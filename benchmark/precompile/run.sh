#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "usage: $0 OUTPUT_DIR LABEL=CHECKOUT [LABEL=CHECKOUT ...]" >&2
    echo "environment: QS_PRECOMPILE_BUILDS, QS_PRECOMPILE_SAMPLES, QS_PRECOMPILE_SCENARIOS, QS_PRECOMPILE_EXTRA_SCENARIOS" >&2
    exit 2
}

[[ $# -ge 3 ]] || usage

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
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
julia=${JULIA:-julia}
expected_julia='julia version 1.12.6'

[[ $builds =~ ^[1-9][0-9]*$ ]] || { echo "QS_PRECOMPILE_BUILDS must be a positive integer" >&2; exit 2; }
[[ $samples =~ ^[1-9][0-9]*$ ]] || { echo "QS_PRECOMPILE_SAMPLES must be a positive integer" >&2; exit 2; }
command -v "$julia" >/dev/null 2>&1 || { echo "Julia executable not found: $julia" >&2; exit 2; }
julia_version=$("$julia" --version)
if [[ $julia_version != "$expected_julia" && ${QS_PRECOMPILE_ALLOW_JULIA_MISMATCH:-0} != 1 ]]; then
    echo "cold-start comparisons require $expected_julia (found $julia_version)" >&2
    echo "set QS_PRECOMPILE_ALLOW_JULIA_MISMATCH=1 only for a non-reportable smoke run" >&2
    exit 2
fi
[[ $(uname -s) == Linux ]] || {
    echo "the cold-start harness currently requires GNU/Linux" >&2
    exit 2
}
IFS=',' read -r -a scenarios <<< "$scenario_list"
[[ ${#scenarios[@]} -gt 0 ]] || { echo "QS_PRECOMPILE_SCENARIOS must not be empty" >&2; exit 2; }
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
    [[ -n $label && $label != *$'\t'* && $label != *$'\n'* ]] || {
        echo "variant labels must be nonempty and must not contain tabs or newlines" >&2
        exit 2
    }
    [[ -f "$checkout/Project.toml" && -d "$checkout/src" ]] || {
        echo "not a QuantumSavory checkout: $checkout" >&2
        exit 2
    }
    checkout=$(cd -- "$checkout" && pwd -P)
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
julia_flags=(--startup-file=no --history-file=no --threads=1)

echo "Preparing one consumer manifest and seed depot..." >&2
JULIA_DEPOT_PATH="$seed_depot" "$julia" "${julia_flags[@]}" -e '
    using Pkg
    Pkg.activate(ARGS[1])
    Pkg.develop(path=ARGS[2])
    Pkg.add(["ConcurrentSim", "Gabs"])
    Pkg.instantiate()
' "$environment_dir" "$checkout_link"

manifest_path="$environment_dir/Manifest.toml"
[[ -f $manifest_path ]] || { echo "consumer manifest was not created" >&2; exit 1; }
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

cp -- "$environment_dir/Project.toml" "$consumer_project_path"
cp -- "$manifest_path" "$consumer_manifest_path"
sed -i -- "s|path = \"$checkout_link\"|path = \"__QUANTUMSAVORY_CHECKOUT__\"|" "$consumer_manifest_path"
grep -q 'path = "__QUANTUMSAVORY_CHECKOUT__"' "$consumer_manifest_path" || {
    echo "failed to replace the temporary QuantumSavory path in the copied Manifest" >&2
    exit 1
}

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
    echo "scenarios=$scenario_list"
    echo "extra_scenarios=$extra_scenario_list"
    echo "manifest_sha256=$(sha256sum "$manifest_path" | awk '{print $1}')"
    for index in "${!labels[@]}"; do
        echo "variant.${labels[$index]}.checkout=${checkouts[$index]}"
        echo "variant.${labels[$index]}.commit=${commits[$index]}"
    done
} > "$metadata_path"

printf '%s\n' $'comparison\tlabel\tcheckout\tcommit\tbuild\tsample\tscenario\tbuild_seconds\tcache_bytes\timport_seconds\tfirst_seconds\tfirst_compile_seconds\tfirst_recompile_seconds\ttotal_seconds\twarm_seconds\twarm_compile_seconds\twarm_recompile_seconds' > "$raw_path"

export JULIA_PKG_OFFLINE=true
for build in $(seq 1 "$builds"); do
    for candidate_index in $(seq 1 $((${#labels[@]} - 1))); do
        comparison=${labels[$candidate_index]}
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

        for index in 0 "$candidate_index"; do
            verify_checkout "$index"
            label=${labels[$index]}
            checkout=${checkouts[$index]}
            commit=${commits[$index]}
            ln -sfn -- "$checkout" "$checkout_link"

            if [[ $index -eq 0 ]]; then
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
