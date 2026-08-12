#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "usage: $0 OUTPUT_DIR LABEL=CHECKOUT [LABEL=CHECKOUT ...]" >&2
    echo "environment: QS_PRECOMPILE_BUILDS, QS_PRECOMPILE_SAMPLES, QS_PRECOMPILE_SCENARIOS, QS_PRECOMPILE_EXTRA_SCENARIOS, QS_PRECOMPILE_BASELINES, QS_PRECOMPILE_CONSUMER_PROJECT, QS_PRECOMPILE_CONSUMER_MANIFEST" >&2
    exit 2
}

rewrite_quantumsavory_manifest_path() {
    local input_path=$1
    local output_path=$2
    local old_path=$3
    local new_path=$4
    if ! awk -v old_path="$old_path" -v new_path="$new_path" '
        BEGIN {
            package_header = "[[deps.QuantumSavory]]"
            old_line = "path = \"" old_path "\""
            new_line = "path = \"" new_path "\""
        }
        {
            remainder = $0
            while ((position = index(remainder, old_path)) != 0) {
                occurrences += 1
                remainder = substr(remainder, position + length(old_path))
            }
            if ($0 == package_header) {
                package_stanzas += 1
                in_package = 1
            } else if ($0 ~ /^\[\[deps\./) {
                in_package = 0
            }
            if ($0 == old_line) {
                path_lines += 1
                in_package || misplaced_path = 1
                print new_line
            } else {
                print
            }
        }
        END {
            if (package_stanzas != 1 || occurrences != 1 || path_lines != 1 || misplaced_path)
                exit 42
        }
    ' "$input_path" > "$output_path"; then
        rm -f -- "$output_path"
        return 1
    fi
}

validate_consumer_project() {
    local project_path=$1
    cmp -s -- <(printf '%s\n' \
        '[deps]' \
        'ConcurrentSim = "6ed1e86c-fcaf-46a9-97e0-2b26a2cdb499"' \
        'Gabs = "0eb812ee-a11f-4f5e-b8d4-bb8a44f06f50"' \
        'QuantumSavory = "2de2e421-972c-4cb5-a0c3-999c85908079"') "$project_path"
}

[[ $# -ge 3 ]] || usage

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
harness_root=$(cd -- "$script_dir/../.." && pwd -P)
harness_commit=$(git -C "$harness_root" rev-parse HEAD 2>/dev/null || echo unavailable)
harness_run_sha256=$(sha256sum "$script_dir/run.sh" | awk '{print $1}')
harness_scenarios_sha256=$(sha256sum "$script_dir/scenarios.jl" | awk '{print $1}')
harness_summarize_sha256=$(sha256sum "$script_dir/summarize.jl" | awk '{print $1}')
output_dir=$1
shift
mkdir -p -- "$output_dir"
output_dir=$(cd -- "$output_dir" && pwd -P)

raw_path="$output_dir/raw.tsv"
summary_path="$output_dir/summary.tsv"
build_summary_path="$output_dir/build-summary.tsv"
markdown_path="$output_dir/summary.md"
metadata_path="$output_dir/metadata.txt"
consumer_project_path="$output_dir/consumer-Project.toml"
consumer_manifest_path="$output_dir/consumer-Manifest.toml"
for path in "$raw_path" "$summary_path" "$build_summary_path" "$markdown_path" "$metadata_path" "$consumer_project_path" "$consumer_manifest_path"; do
    [[ ! -e "$path" ]] || {
        echo "refusing to overwrite existing result file: $path" >&2
        exit 2
    }
done

builds=${QS_PRECOMPILE_BUILDS:-1}
samples=${QS_PRECOMPILE_SAMPLES:-2}
scenario_list=${QS_PRECOMPILE_SCENARIOS:-bell,entangler}
extra_scenario_list=${QS_PRECOMPILE_EXTRA_SCENARIOS:-}
baseline_map_list=${QS_PRECOMPILE_BASELINES:-}
reuse_consumer_project=${QS_PRECOMPILE_CONSUMER_PROJECT:-}
reuse_consumer_manifest=${QS_PRECOMPILE_CONSUMER_MANIFEST:-}
julia=${JULIA:-julia}
expected_julia='julia version 1.12.6'
token_pattern='^[A-Za-z0-9][A-Za-z0-9_.-]*$'
token_list_pattern='^[A-Za-z0-9][A-Za-z0-9_.-]*(,[A-Za-z0-9][A-Za-z0-9_.-]*)*$'
mapping_list_pattern='^[A-Za-z0-9][A-Za-z0-9_.-]*=[A-Za-z0-9][A-Za-z0-9_.-]*(,[A-Za-z0-9][A-Za-z0-9_.-]*=[A-Za-z0-9][A-Za-z0-9_.-]*)*$'

[[ $builds =~ ^[1-9][0-9]*$ ]] || { echo "QS_PRECOMPILE_BUILDS must be a positive integer" >&2; exit 2; }
[[ $samples =~ ^[1-9][0-9]*$ ]] || { echo "QS_PRECOMPILE_SAMPLES must be a positive integer" >&2; exit 2; }
[[ $scenario_list =~ $token_list_pattern ]] || {
    echo "QS_PRECOMPILE_SCENARIOS must be a comma-separated list of scenario tokens" >&2
    exit 2
}
[[ -z $extra_scenario_list || $extra_scenario_list =~ $mapping_list_pattern ]] || {
    echo "QS_PRECOMPILE_EXTRA_SCENARIOS must be a comma-separated LABEL=SCENARIO list" >&2
    exit 2
}
[[ -z $baseline_map_list || $baseline_map_list =~ $mapping_list_pattern ]] || {
    echo "QS_PRECOMPILE_BASELINES must be a comma-separated CANDIDATE=BASELINE list" >&2
    exit 2
}
if [[ -n $reuse_consumer_project || -n $reuse_consumer_manifest ]]; then
    [[ -n $reuse_consumer_project && -n $reuse_consumer_manifest ]] || {
        echo "QS_PRECOMPILE_CONSUMER_PROJECT and QS_PRECOMPILE_CONSUMER_MANIFEST must be set together" >&2
        exit 2
    }
    for source_path in "$reuse_consumer_project" "$reuse_consumer_manifest"; do
        [[ $source_path != *$'\t'* && $source_path != *$'\n'* && $source_path != *$'\r'* ]] || {
            echo "consumer environment paths must not contain tabs or line endings" >&2
            exit 2
        }
        [[ -f $source_path && -r $source_path ]] || {
            echo "consumer environment input is not a readable regular file: $source_path" >&2
            exit 2
        }
    done
    reuse_consumer_project=$(realpath -e -- "$reuse_consumer_project")
    reuse_consumer_manifest=$(realpath -e -- "$reuse_consumer_manifest")
    for source_path in "$reuse_consumer_project" "$reuse_consumer_manifest"; do
        [[ $source_path != *$'\t'* && $source_path != *$'\n'* && $source_path != *$'\r'* ]] || {
            echo "canonical consumer environment paths must not contain tabs or line endings" >&2
            exit 2
        }
    done
fi
command -v "$julia" >/dev/null 2>&1 || { echo "Julia executable not found: $julia" >&2; exit 2; }
julia_version=$("$julia" --version)
if [[ $julia_version != "$expected_julia" && ${QS_PRECOMPILE_ALLOW_JULIA_MISMATCH:-0} != 1 ]]; then
    echo "cold-start comparisons require $expected_julia (found $julia_version)" >&2
    echo "set QS_PRECOMPILE_ALLOW_JULIA_MISMATCH=1 only for a non-reportable smoke run" >&2
    exit 2
fi

baseline_candidates=()
baseline_labels=()
if [[ -n $baseline_map_list ]]; then
    IFS=',' read -r -a baseline_specifications <<< "$baseline_map_list"
    for specification in "${baseline_specifications[@]}"; do
        [[ $specification == *=* ]] || {
            echo "QS_PRECOMPILE_BASELINES entries must have CANDIDATE=BASELINE form" >&2
            exit 2
        }
        baseline_candidate=${specification%%=*}
        baseline_label=${specification#*=}
        [[ -n $baseline_candidate && -n $baseline_label ]] || {
            echo "invalid baseline entry: $specification" >&2
            exit 2
        }
        baseline_candidates+=("$baseline_candidate")
        baseline_labels+=("$baseline_label")
    done
fi
[[ $(uname -s) == Linux ]] || {
    echo "the cold-start harness currently requires GNU/Linux" >&2
    exit 2
}
IFS=',' read -r -a scenarios <<< "$scenario_list"
[[ ${#scenarios[@]} -gt 0 ]] || { echo "QS_PRECOMPILE_SCENARIOS must not be empty" >&2; exit 2; }
for scenario_index in "${!scenarios[@]}"; do
    for previous_index in "${!scenarios[@]}"; do
        [[ $previous_index -ge $scenario_index ]] && break
        [[ ${scenarios[$previous_index]} != "${scenarios[$scenario_index]}" ]] || {
            echo "duplicate scenario: ${scenarios[$scenario_index]}" >&2
            exit 2
        }
    done
done
extra_scenario_labels=()
extra_scenarios=()
if [[ -n $extra_scenario_list ]]; then
    IFS=',' read -r -a extra_specifications <<< "$extra_scenario_list"
    for specification in "${extra_specifications[@]}"; do
        [[ $specification == *=* ]] || {
            echo "QS_PRECOMPILE_EXTRA_SCENARIOS entries must have LABEL=SCENARIO form" >&2
            exit 2
        }
        extra_label=${specification%%=*}
        extra_scenario=${specification#*=}
        [[ -n $extra_label && -n $extra_scenario && $extra_scenario != *[[:space:]]* ]] || {
            echo "invalid extra scenario entry: $specification" >&2
            exit 2
        }
        for extra_index in "${!extra_scenarios[@]}"; do
            [[ ${extra_scenario_labels[$extra_index]} != "$extra_label" || ${extra_scenarios[$extra_index]} != "$extra_scenario" ]] || {
                echo "duplicate extra scenario: $specification" >&2
                exit 2
            }
        done
        extra_scenario_labels+=("$extra_label")
        extra_scenarios+=("$extra_scenario")
    done
fi

labels=()
checkouts=()
for specification in "$@"; do
    [[ $specification == *=* ]] || usage
    label=${specification%%=*}
    checkout=${specification#*=}
    [[ $label =~ $token_pattern ]] || {
        echo "variant labels must start with an ASCII letter or digit and contain only letters, digits, dots, underscores, or hyphens" >&2
        exit 2
    }
    [[ -n $checkout && $checkout != *$'\t'* && $checkout != *$'\n'* ]] || {
        echo "variant checkouts must be nonempty and must not contain tabs or newlines" >&2
        exit 2
    }
    [[ -f "$checkout/Project.toml" && -d "$checkout/src" ]] || {
        echo "not a QuantumSavory checkout: $checkout" >&2
        exit 2
    }
    checkout=$(cd -- "$checkout" && pwd -P)
    [[ $checkout != *$'\t'* && $checkout != *$'\n'* ]] || {
        echo "canonical variant checkout paths must not contain tabs or newlines" >&2
        exit 2
    }
    for existing_label in "${labels[@]}"; do
        [[ $label != "$existing_label" ]] || { echo "duplicate variant label: $label" >&2; exit 2; }
    done
    labels+=("$label")
    checkouts+=("$checkout")
done

commits=()
for index in "${!labels[@]}"; do
    checkout=${checkouts[$index]}
    commits+=("$(git -C "$checkout" rev-parse HEAD)")
    if [[ -n $(git -C "$checkout" status --porcelain) && ${QS_PRECOMPILE_ALLOW_DIRTY:-0} != 1 ]]; then
        echo "variant checkout is dirty; commit it or set QS_PRECOMPILE_ALLOW_DIRTY=1 for a non-reportable smoke run: ${labels[$index]}" >&2
        exit 1
    fi
done

verify_checkout() {
    local index=$1
    local checkout=${checkouts[$index]}
    local expected_commit=${commits[$index]}
    [[ $(git -C "$checkout" rev-parse HEAD) == "$expected_commit" ]] || {
        echo "variant HEAD changed during measurement: ${labels[$index]}" >&2
        exit 1
    }
    if [[ -n $(git -C "$checkout" status --porcelain) && ${QS_PRECOMPILE_ALLOW_DIRTY:-0} != 1 ]]; then
        echo "variant became dirty during measurement: ${labels[$index]}" >&2
        exit 1
    fi
}

for checkout in "${checkouts[@]:1}"; do
    cmp -s -- "${checkouts[0]}/Project.toml" "$checkout/Project.toml" || {
        echo "all variants must use identical Project.toml dependency metadata" >&2
        exit 1
    }
done
for extra_label in "${extra_scenario_labels[@]}"; do
    known_label=false
    for label in "${labels[@]}"; do
        [[ $label == "$extra_label" ]] && known_label=true
    done
    $known_label || {
        echo "extra scenario refers to an unknown variant label: $extra_label" >&2
        exit 2
    }
    [[ $extra_label != "${labels[0]}" ]] || {
        echo "extra scenarios must name a candidate, not the baseline" >&2
        exit 2
    }
done
for mapping_index in "${!baseline_candidates[@]}"; do
    baseline_candidate=${baseline_candidates[$mapping_index]}
    baseline_label=${baseline_labels[$mapping_index]}
    candidate_known=false
    baseline_known=false
    for label in "${labels[@]}"; do
        [[ $label == "$baseline_candidate" ]] && candidate_known=true
        [[ $label == "$baseline_label" ]] && baseline_known=true
    done
    $candidate_known || {
        echo "baseline map refers to an unknown candidate label: $baseline_candidate" >&2
        exit 2
    }
    $baseline_known || {
        echo "baseline map refers to an unknown baseline label: $baseline_label" >&2
        exit 2
    }
    [[ $baseline_candidate != "${labels[0]}" ]] || {
        echo "the first variant cannot be a mapped candidate: $baseline_candidate" >&2
        exit 2
    }
    [[ $baseline_candidate != "$baseline_label" ]] || {
        echo "a candidate cannot be its own baseline: $baseline_candidate" >&2
        exit 2
    }
    for previous_index in "${!baseline_candidates[@]}"; do
        [[ $previous_index -ge $mapping_index ]] && break
        [[ ${baseline_candidates[$previous_index]} != "$baseline_candidate" ]] || {
            echo "duplicate baseline map for candidate: $baseline_candidate" >&2
            exit 2
        }
    done
done

candidate_baseline_indices=()
for ((candidate_index = 1; candidate_index < ${#labels[@]}; candidate_index++)); do
    baseline_index=0
    for mapping_index in "${!baseline_candidates[@]}"; do
        [[ ${baseline_candidates[$mapping_index]} == "${labels[$candidate_index]}" ]] || continue
        for label_index in "${!labels[@]}"; do
            if [[ ${labels[$label_index]} == "${baseline_labels[$mapping_index]}" ]]; then
                baseline_index=$label_index
                break
            fi
        done
        break
    done
    candidate_baseline_indices[$candidate_index]=$baseline_index
done

set_comparison_order() {
    local build_number=$1
    local candidate_index
    comparison_indices=()
    if ((build_number % 2 == 1)); then
        for ((candidate_index = 1; candidate_index < ${#labels[@]}; candidate_index++)); do
            comparison_indices+=("$candidate_index")
        done
    else
        for ((candidate_index = ${#labels[@]} - 1; candidate_index >= 1; candidate_index--)); do
            comparison_indices+=("$candidate_index")
        done
    fi
}

set_pair_order() {
    local build_number=$1
    local candidate_index=$2
    local baseline_index=${candidate_baseline_indices[$candidate_index]}
    if (((build_number + candidate_index) % 2 == 1)); then
        pair_indices=("$baseline_index" "$candidate_index")
    else
        pair_indices=("$candidate_index" "$baseline_index")
    fi
}

temporary_root=$(mktemp -d "${TMPDIR:-/tmp}/quantumsavory-precompile.XXXXXX")
cleanup() {
    if [[ ${QS_PRECOMPILE_KEEP_TMP:-0} == 1 ]]; then
        echo "kept temporary benchmark data at $temporary_root" >&2
    else
        rm -rf -- "$temporary_root"
    fi
}
trap cleanup EXIT

environment_dir="$temporary_root/environment"
seed_depot="$temporary_root/seed-depot"
checkout_link="$temporary_root/checkout"
mkdir -p -- "$environment_dir" "$seed_depot"
ln -s -- "${checkouts[0]}" "$checkout_link"
[[ $checkout_link != *$'\t'* && $checkout_link != *$'\n'* && $checkout_link != *$'\r'* && $checkout_link != *'"'* && $checkout_link != *'\'* ]] || {
    echo "temporary checkout link cannot be represented safely in the consumer Manifest: $checkout_link" >&2
    exit 1
}

export JULIA_NUM_THREADS=1
export JULIA_NUM_PRECOMPILE_TASKS=1
export JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_LOAD_PATH='@:@stdlib'
export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
export LC_ALL=C
unset QS_PRECOMPILE_TRACE
unset JULIA_PKG_OFFLINE
julia_flags=(--startup-file=no --history-file=no --threads=1)

echo "Preparing one consumer manifest and seed depot..." >&2
consumer_environment_mode=resolved
consumer_environment_source_project=
consumer_environment_source_manifest=
consumer_environment_source_project_sha256=
consumer_environment_source_manifest_sha256=
if [[ -n $reuse_consumer_project ]]; then
    consumer_environment_mode=reused
    consumer_environment_source_project=$reuse_consumer_project
    consumer_environment_source_manifest=$reuse_consumer_manifest
    validate_consumer_project "$reuse_consumer_project" || {
        echo "reused consumer Project does not match the harness-generated Project" >&2
        exit 2
    }
    cp -- "$reuse_consumer_project" "$environment_dir/Project.toml"
    rewrite_quantumsavory_manifest_path \
        "$reuse_consumer_manifest" "$environment_dir/Manifest.toml" \
        '__QUANTUMSAVORY_CHECKOUT__' "$checkout_link" || {
        echo "reused consumer Manifest must contain exactly one QuantumSavory checkout placeholder in its QuantumSavory path entry" >&2
        exit 2
    }
    consumer_environment_source_project_sha256=$(sha256sum "$reuse_consumer_project" | awk '{print $1}')
    consumer_environment_source_manifest_sha256=$(sha256sum "$reuse_consumer_manifest" | awk '{print $1}')
    JULIA_DEPOT_PATH="$seed_depot" "$julia" "${julia_flags[@]}" -e '
        using Pkg
        Pkg.activate(ARGS[1])
        Pkg.instantiate()
    ' "$environment_dir"
    cmp -s -- "$reuse_consumer_project" "$environment_dir/Project.toml" || {
        echo "Pkg.instantiate changed the reused consumer Project" >&2
        exit 1
    }
    reused_normalized_manifest="$temporary_root/reused-normalized-Manifest.toml"
    rewrite_quantumsavory_manifest_path \
        "$environment_dir/Manifest.toml" "$reused_normalized_manifest" \
        "$checkout_link" '__QUANTUMSAVORY_CHECKOUT__' || {
        echo "Pkg.instantiate did not preserve the reused QuantumSavory Manifest path" >&2
        exit 1
    }
    cmp -s -- "$reuse_consumer_manifest" "$reused_normalized_manifest" || {
        echo "Pkg.instantiate changed the reused consumer Manifest" >&2
        exit 1
    }
else
    JULIA_DEPOT_PATH="$seed_depot" "$julia" "${julia_flags[@]}" -e '
        using Pkg
        Pkg.activate(ARGS[1])
        Pkg.develop(path=ARGS[2])
        Pkg.add(["ConcurrentSim", "Gabs"])
        Pkg.instantiate()
    ' "$environment_dir" "$checkout_link"
fi

manifest_path="$environment_dir/Manifest.toml"
[[ -f $manifest_path ]] || { echo "consumer manifest was not created" >&2; exit 1; }
resolved_manifest_sha256=$(sha256sum "$manifest_path" | awk '{print $1}')
manifest_checkout=$(awk '
    $0 == "[[deps.QuantumSavory]]" { in_package = 1; next }
    in_package && /^\[\[deps\./ { in_package = 0 }
    in_package && /^path = / {
        sub(/^path = "/, "")
        sub(/"$/, "")
        print
        exit
    }
' "$manifest_path")
[[ $manifest_checkout == "$checkout_link" ]] || {
    echo "consumer Manifest did not preserve the stable checkout link: $manifest_checkout" >&2
    exit 1
}

JULIA_DEPOT_PATH="$seed_depot" "$julia" "${julia_flags[@]}" --project="$environment_dir" -e 'using QuantumSavory'
find "$seed_depot/compiled" -type f -path '*/QuantumSavory/*' -delete 2>/dev/null || true
find "$seed_depot/compiled" -type d -path '*/QuantumSavory' -empty -delete 2>/dev/null || true

validate_consumer_project "$environment_dir/Project.toml" || {
    echo "consumer Project does not match the expected QuantumSavory, ConcurrentSim, and Gabs environment" >&2
    exit 1
}
cp -- "$environment_dir/Project.toml" "$consumer_project_path"
rewrite_quantumsavory_manifest_path \
    "$manifest_path" "$consumer_manifest_path" \
    "$checkout_link" '__QUANTUMSAVORY_CHECKOUT__' || {
    echo "failed to normalize exactly one QuantumSavory path in the copied Manifest" >&2
    exit 1
}
if [[ $consumer_environment_mode == reused ]]; then
    cmp -s -- "$reuse_consumer_project" "$consumer_project_path" || {
        echo "copied consumer Project differs from the reused input" >&2
        exit 1
    }
    cmp -s -- "$reuse_consumer_manifest" "$consumer_manifest_path" || {
        echo "copied consumer Manifest differs from the reused input" >&2
        exit 1
    }
fi
consumer_project_sha256=$(sha256sum "$consumer_project_path" | awk '{print $1}')
normalized_manifest_sha256=$(sha256sum "$consumer_manifest_path" | awk '{print $1}')

{
    echo "date_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "julia=$julia_version"
    echo "kernel=$(uname -srvmo)"
    if [[ -r /etc/os-release ]]; then
        os_name=$(awk '$0 ~ /^PRETTY_NAME=/ { sub(/^[^=]*=/, ""); sub(/^"/, ""); sub(/"$/, ""); print; exit }' /etc/os-release)
        echo "os=$os_name"
    fi
    if command -v lscpu >/dev/null 2>&1; then
        echo "cpu=$(lscpu | awk -F: '/Model name/ { sub(/^[[:space:]]+/, "", $2); print $2; exit }')"
    fi
    echo "julia_num_threads=$JULIA_NUM_THREADS"
    echo "julia_num_precompile_tasks=$JULIA_NUM_PRECOMPILE_TASKS"
    echo "openblas_num_threads=$OPENBLAS_NUM_THREADS"
    echo "omp_num_threads=$OMP_NUM_THREADS"
    echo "julia_load_path=$JULIA_LOAD_PATH"
    echo "pkg_auto_precompile=$JULIA_PKG_PRECOMPILE_AUTO"
    echo "pkg_offline_during_measurement=true"
    echo "builds=$builds"
    echo "recorded_samples_per_build=$samples"
    echo "discarded_warmups_per_build_and_scenario=1"
    echo "total_metric=wall_import_start_to_first_task_end"
    echo "scenarios=$scenario_list"
    echo "extra_scenarios=$extra_scenario_list"
    echo "candidate_baselines=$baseline_map_list"
    echo "schedule_policy=counterbalanced-v1"
    echo "schedule_candidate_index=one_based_candidate_argument_position"
    echo "schedule_comparison_policy=ascending_candidate_index_on_odd_builds_descending_candidate_index_on_even_builds"
    echo "schedule_pair_policy=baseline_then_candidate_when_build_plus_candidate_index_is_odd_candidate_then_baseline_when_even"
    for ((schedule_candidate_index = 1; schedule_candidate_index < ${#labels[@]}; schedule_candidate_index++)); do
        echo "schedule.candidate_index.${labels[$schedule_candidate_index]}=$schedule_candidate_index"
    done
    for ((schedule_build = 1; schedule_build <= builds; schedule_build++)); do
        set_comparison_order "$schedule_build"
        schedule_value=
        for schedule_candidate_index in "${comparison_indices[@]}"; do
            set_pair_order "$schedule_build" "$schedule_candidate_index"
            baseline_index=${candidate_baseline_indices[$schedule_candidate_index]}
            pair_value=
            for schedule_variant_index in "${pair_indices[@]}"; do
                if [[ $schedule_variant_index -eq $baseline_index ]]; then
                    schedule_role=baseline
                else
                    schedule_role=candidate
                fi
                [[ -z $pair_value ]] || pair_value+=,
                pair_value+="$schedule_role:${labels[$schedule_variant_index]}"
            done
            [[ -z $schedule_value ]] || schedule_value+=';'
            schedule_value+="comparison:${labels[$schedule_candidate_index]},$pair_value"
        done
        echo "schedule.build.$schedule_build=$schedule_value"
    done
    echo "consumer_environment_mode=$consumer_environment_mode"
    echo "consumer_project_sha256=$consumer_project_sha256"
    if [[ $consumer_environment_mode == reused ]]; then
        echo "consumer_environment_source_project=$consumer_environment_source_project"
        echo "consumer_environment_source_manifest=$consumer_environment_source_manifest"
        echo "consumer_environment_source_project_sha256=$consumer_environment_source_project_sha256"
        echo "consumer_environment_source_manifest_sha256=$consumer_environment_source_manifest_sha256"
    fi
    echo "manifest_sha256=$normalized_manifest_sha256"
    echo "resolved_manifest_sha256=$resolved_manifest_sha256"
    echo "harness_commit=$harness_commit"
    echo "harness_run_sha256=$harness_run_sha256"
    echo "harness_scenarios_sha256=$harness_scenarios_sha256"
    echo "harness_summarize_sha256=$harness_summarize_sha256"
    for index in "${!labels[@]}"; do
        echo "variant.${labels[$index]}.checkout=${checkouts[$index]}"
        echo "variant.${labels[$index]}.commit=${commits[$index]}"
    done
} > "$metadata_path"

printf '%s\n' $'comparison\tlabel\tcheckout\tcommit\tbuild\tsample\tscenario\tbuild_seconds\tcache_bytes\timport_seconds\tfirst_seconds\tfirst_compile_seconds\tfirst_recompile_seconds\ttotal_seconds\twarm_seconds\twarm_compile_seconds\twarm_recompile_seconds' > "$raw_path"

export JULIA_PKG_OFFLINE=true
for build in $(seq 1 "$builds"); do
    set_comparison_order "$build"
    for candidate_index in "${comparison_indices[@]}"; do
        comparison=${labels[$candidate_index]}
        baseline_index=${candidate_baseline_indices[$candidate_index]}
        variant_scenarios=("${scenarios[@]}")
        for extra_index in "${!extra_scenarios[@]}"; do
            if [[ ${extra_scenario_labels[$extra_index]} == "$comparison" ]]; then
                extra_scenario=${extra_scenarios[$extra_index]}
                already_selected=false
                for selected_scenario in "${variant_scenarios[@]}"; do
                    [[ $selected_scenario == "$extra_scenario" ]] && already_selected=true
                done
                $already_selected || variant_scenarios+=("$extra_scenario")
            fi
        done

        set_pair_order "$build" "$candidate_index"
        for index in "${pair_indices[@]}"; do
            verify_checkout "$index"
            label=${labels[$index]}
            checkout=${checkouts[$index]}
            commit=${commits[$index]}
            ln -sfn -- "$checkout" "$checkout_link"

            if [[ $index -eq $baseline_index ]]; then
                role=baseline
            else
                role=candidate
            fi
            run_depot="$temporary_root/run-$candidate_index-$role-$build"
            mkdir -p -- "$run_depot"
            echo "Building cache for $comparison: $label ($build/$builds)..." >&2
            build_started=$(date +%s.%N)
            JULIA_DEPOT_PATH="$run_depot:$seed_depot" "$julia" "${julia_flags[@]}" --project="$environment_dir" -e 'using QuantumSavory'
            build_finished=$(date +%s.%N)
            build_seconds=$(awk -v started="$build_started" -v finished="$build_finished" 'BEGIN { printf "%.9f", finished - started }')
            cache_bytes=$(find "$run_depot/compiled" -type f -path '*/QuantumSavory/*' -printf '%s\n' | awk '{ total += $1 } END { print total + 0 }')
            [[ $cache_bytes -gt 0 ]] || { echo "QuantumSavory cache was not written to the run depot" >&2; exit 1; }

            for scenario in "${variant_scenarios[@]}"; do
                [[ -n $scenario && $scenario != *[[:space:]]* ]] || {
                    echo "scenario names must be nonempty and contain no whitespace: $scenario" >&2
                    exit 2
                }
                echo "Discarding filesystem warm-up for $comparison: $label/$scenario build $build..." >&2
                JULIA_DEPOT_PATH="$run_depot:$seed_depot" "$julia" "${julia_flags[@]}" --project="$environment_dir" "$script_dir/scenarios.jl" "$scenario" >/dev/null

                for sample in $(seq 1 "$samples"); do
                    echo "Sampling $comparison: $label/$scenario build $build ($sample/$samples)..." >&2
                    scenario_output=$(JULIA_DEPOT_PATH="$run_depot:$seed_depot" "$julia" "${julia_flags[@]}" --project="$environment_dir" "$script_dir/scenarios.jl" "$scenario")
                    result=$(printf '%s\n' "$scenario_output" | awk -F '\t' '$1 == "RESULT" { print; count += 1 } END { if (count != 1) exit 1 }') || {
                        echo "scenario did not emit exactly one RESULT row: $label/$scenario" >&2
                        exit 1
                    }
                    IFS=$'\t' read -r marker measured_scenario import_seconds first_seconds first_compile first_recompile total_seconds warm_seconds warm_compile warm_recompile <<< "$result"
                    [[ $marker == RESULT && $measured_scenario == "$scenario" ]] || {
                        echo "malformed scenario result: $result" >&2
                        exit 1
                    }
                    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                        "$comparison" "$label" "$checkout" "$commit" "$build" "$sample" "$scenario" \
                        "$build_seconds" "$cache_bytes" "$import_seconds" "$first_seconds" \
                        "$first_compile" "$first_recompile" "$total_seconds" "$warm_seconds" \
                        "$warm_compile" "$warm_recompile" >> "$raw_path"
                done
            done
        done
    done
done

for index in "${!labels[@]}"; do
    verify_checkout "$index"
done

JULIA_DEPOT_PATH="$seed_depot" "$julia" "${julia_flags[@]}" "$script_dir/summarize.jl" \
    "$raw_path" "$summary_path" "$build_summary_path" "$markdown_path"
echo "Wrote $raw_path, $summary_path, $build_summary_path, and $markdown_path" >&2
