using Printf
using Statistics

length(ARGS) == 4 || error("usage: summarize.jl RAW_TSV SUMMARY_TSV BUILD_SUMMARY_TSV SUMMARY_MD")
raw_path, summary_path, build_summary_path, markdown_path = ARGS

lines = readlines(raw_path)
isempty(lines) && error("raw result file is empty: $raw_path")
header = split(first(lines), '\t')
rows = map(Iterators.drop(lines, 1)) do line
    fields = split(line, '\t'; keepempty=true)
    length(fields) == length(header) || error("raw result row has $(length(fields)) fields; expected $(length(header))")
    Dict(zip(header, fields))
end
isempty(rows) && error("raw result file contains no measurements: $raw_path")
comparisons = unique(row["comparison"] for row in rows)

number(row, name) = parse(Float64, row[name])
median_iqr(values) = (median(values), quantile(values, 0.75) - quantile(values, 0.25))

function comparison_labels(comparison)
    labels = unique(row["label"] for row in rows if row["comparison"] == comparison)
    length(labels) == 2 || error("comparison $comparison must have one baseline and one candidate")
    comparison in labels || error("comparison $comparison has no matching candidate label")
    baseline_labels = filter(!=(comparison), labels)
    length(baseline_labels) == 1 || error("comparison $comparison must have one distinct baseline")
    return (only(baseline_labels), comparison)
end

function comparison_scenarios(comparison)
    return unique(row["scenario"] for row in rows if row["comparison"] == comparison)
end

function sample_stats(comparison, label, scenario, field)
    values = [
        number(row, field) for row in rows
        if row["comparison"] == comparison && row["label"] == label && row["scenario"] == scenario
    ]
    isempty(values) && error("no $field samples for $comparison: $label/$scenario")
    return median_iqr(values)
end

function build_stats(comparison, label, field)
    values_by_build = Dict{String,Float64}()
    for row in rows
        row["comparison"] == comparison && row["label"] == label || continue
        values_by_build[row["build"]] = number(row, field)
    end
    isempty(values_by_build) && error("no $field build results for $comparison: $label")
    return median_iqr(collect(values(values_by_build)))
end

function sample_medians_by_build(comparison, label, scenario, field)
    values_by_build = Dict{String,Vector{Float64}}()
    for row in rows
        row["comparison"] == comparison && row["label"] == label && row["scenario"] == scenario || continue
        push!(get!(Vector{Float64}, values_by_build, row["build"]), number(row, field))
    end
    return Dict(build => median(values) for (build, values) in values_by_build)
end

function material_counts(comparison, label, scenario)
    baseline_label = first(comparison_labels(comparison))
    baseline = sample_medians_by_build(comparison, baseline_label, scenario, "total_seconds")
    variant = sample_medians_by_build(comparison, label, scenario, "total_seconds")
    builds = sort!(collect(intersect(keys(baseline), keys(variant))); by=x -> parse(Int, x))
    improved = count(builds) do build
        threshold = max(0.050, 0.05 * baseline[build])
        variant[build] <= baseline[build] - threshold
    end
    regressed = count(builds) do build
        threshold = max(0.050, 0.05 * baseline[build])
        variant[build] >= baseline[build] + threshold
    end
    return improved, regressed, length(builds)
end

delta(value, baseline) = value - baseline
percent_delta(value, baseline) = iszero(baseline) ? NaN : 100 * delta(value, baseline) / baseline
signed(value; digits=2) = @sprintf("%+.*f", digits, value)
measurement(value, iqr; scale=1.0, digits=2) = @sprintf("%.*f [%.*f]", digits, value * scale, digits, iqr * scale)

columns = [
    "comparison", "label", "scenario", "builds", "samples_per_build",
    "build_s_median", "build_s_iqr", "build_delta_s", "build_delta_pct",
    "cache_mib_median", "cache_mib_iqr", "cache_delta_mib", "cache_delta_pct",
    "import_ms_median", "import_ms_iqr", "import_delta_ms", "import_delta_pct",
    "first_ms_median", "first_ms_iqr", "first_delta_ms", "first_delta_pct",
    "compile_ms_median", "compile_ms_iqr", "recompile_ms_median", "recompile_ms_iqr",
    "total_ms_median", "total_ms_iqr", "total_delta_ms", "total_delta_pct",
    "warm_ms_median", "warm_ms_iqr", "warm_delta_ms", "warm_delta_pct",
    "warm_compile_ms_median", "warm_compile_ms_iqr",
    "warm_recompile_ms_median", "warm_recompile_ms_iqr",
    "total_material_improvements", "total_material_regressions", "compared_builds",
]

open(build_summary_path, "w") do io
    println(io, join((
        "comparison", "label", "scenario", "build", "samples",
        "import_ms_median", "first_ms_median", "compile_ms_median",
        "recompile_ms_median", "total_ms_median", "warm_ms_median",
        "warm_compile_ms_median", "warm_recompile_ms_median",
        "baseline_total_ms_median", "total_delta_ms", "total_delta_pct",
        "material_threshold_ms", "material_improvement", "material_regression",
    ), '\t'))
    for comparison in comparisons
        labels = comparison_labels(comparison)
        baseline_label = first(labels)
        for label in labels, scenario in comparison_scenarios(comparison)
            total_by_build = sample_medians_by_build(comparison, label, scenario, "total_seconds")
            isempty(total_by_build) && continue
            baseline_total_by_build = sample_medians_by_build(
                comparison, baseline_label, scenario, "total_seconds"
            )
            for build in sort!(collect(keys(total_by_build)); by=x -> parse(Int, x))
                haskey(baseline_total_by_build, build) || error("baseline has no $scenario build $build")
                matching = [
                    row for row in rows
                    if row["comparison"] == comparison && row["label"] == label &&
                        row["scenario"] == scenario && row["build"] == build
                ]
                med(field) = median(number(row, field) for row in matching)
                total = total_by_build[build]
                baseline_total = baseline_total_by_build[build]
                threshold = max(0.050, 0.05 * baseline_total)
                println(io, join(Any[
                    comparison, label, scenario, build, length(matching),
                    med("import_seconds") * 1e3,
                    med("first_seconds") * 1e3,
                    med("first_compile_seconds") * 1e3,
                    med("first_recompile_seconds") * 1e3,
                    total * 1e3,
                    med("warm_seconds") * 1e3,
                    med("warm_compile_seconds") * 1e3,
                    med("warm_recompile_seconds") * 1e3,
                    baseline_total * 1e3,
                    delta(total, baseline_total) * 1e3,
                    percent_delta(total, baseline_total),
                    threshold * 1e3,
                    total <= baseline_total - threshold,
                    total >= baseline_total + threshold,
                ], '\t'))
            end
        end
    end
end

open(summary_path, "w") do io
    println(io, join(columns, '\t'))
    for comparison in comparisons
        labels = comparison_labels(comparison)
        baseline_label = first(labels)
        for label in labels, scenario in comparison_scenarios(comparison)
            matching = [
                row for row in rows
                if row["comparison"] == comparison && row["label"] == label && row["scenario"] == scenario
            ]
            isempty(matching) && continue

            builds = length(unique(row["build"] for row in matching))
            samples_per_build = unique(
                count(row -> row["build"] == build, matching)
                for build in unique(row["build"] for row in matching)
            )
            length(samples_per_build) == 1 || error("sample count varies by build for $label/$scenario")
            build, build_iqr = build_stats(comparison, label, "build_seconds")
            cache, cache_iqr = build_stats(comparison, label, "cache_bytes")
            import_time, import_iqr = sample_stats(comparison, label, scenario, "import_seconds")
            first_time, first_iqr = sample_stats(comparison, label, scenario, "first_seconds")
            compile_time, compile_iqr = sample_stats(comparison, label, scenario, "first_compile_seconds")
            recompile_time, recompile_iqr = sample_stats(comparison, label, scenario, "first_recompile_seconds")
            total_time, total_iqr = sample_stats(comparison, label, scenario, "total_seconds")
            warm_time, warm_iqr = sample_stats(comparison, label, scenario, "warm_seconds")
            warm_compile, warm_compile_iqr = sample_stats(comparison, label, scenario, "warm_compile_seconds")
            warm_recompile, warm_recompile_iqr = sample_stats(comparison, label, scenario, "warm_recompile_seconds")

            baseline_build = first(build_stats(comparison, baseline_label, "build_seconds"))
            baseline_cache = first(build_stats(comparison, baseline_label, "cache_bytes"))
            baseline_import = first(sample_stats(comparison, baseline_label, scenario, "import_seconds"))
            baseline_first = first(sample_stats(comparison, baseline_label, scenario, "first_seconds"))
            baseline_total = first(sample_stats(comparison, baseline_label, scenario, "total_seconds"))
            baseline_warm = first(sample_stats(comparison, baseline_label, scenario, "warm_seconds"))
            improved, regressed, compared = material_counts(comparison, label, scenario)

            values = Any[
                comparison, label, scenario, builds, only(samples_per_build),
                build, build_iqr, delta(build, baseline_build), percent_delta(build, baseline_build),
                cache / 2.0^20, cache_iqr / 2.0^20, delta(cache, baseline_cache) / 2.0^20, percent_delta(cache, baseline_cache),
                import_time * 1e3, import_iqr * 1e3, delta(import_time, baseline_import) * 1e3, percent_delta(import_time, baseline_import),
                first_time * 1e3, first_iqr * 1e3, delta(first_time, baseline_first) * 1e3, percent_delta(first_time, baseline_first),
                compile_time * 1e3, compile_iqr * 1e3, recompile_time * 1e3, recompile_iqr * 1e3,
                total_time * 1e3, total_iqr * 1e3, delta(total_time, baseline_total) * 1e3, percent_delta(total_time, baseline_total),
                warm_time * 1e3, warm_iqr * 1e3, delta(warm_time, baseline_warm) * 1e3, percent_delta(warm_time, baseline_warm),
                warm_compile * 1e3, warm_compile_iqr * 1e3,
                warm_recompile * 1e3, warm_recompile_iqr * 1e3,
                improved, regressed, compared,
            ]
            println(io, join(values, '\t'))
        end
    end
end

open(markdown_path, "w") do io
    println(io, "# QuantumSavory cold-start summary")
    println(io)
    println(io, "Medians are followed by interquartile ranges in brackets. Each candidate has its own adjacent baseline builds.")
    println(io)
    println(io, "| Comparison | Variant | Scenario | Cache build (s) | Build Δ | Cache (MiB) | Cache Δ | Import (ms) | Import Δ | First task (ms) | First Δ | Compile / recompile (ms) | Total (ms) | Total Δ | Material total Δ builds | Warm task (ms) | Warm compile / recompile (ms) |")
    println(io, "|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    for comparison in comparisons
        labels = comparison_labels(comparison)
        baseline_label = first(labels)
        for label in labels, scenario in comparison_scenarios(comparison)
            any(row -> row["comparison"] == comparison && row["label"] == label && row["scenario"] == scenario, rows) || continue
            build, build_iqr = build_stats(comparison, label, "build_seconds")
            cache, cache_iqr = build_stats(comparison, label, "cache_bytes")
            import_time, import_iqr = sample_stats(comparison, label, scenario, "import_seconds")
            first_time, first_iqr = sample_stats(comparison, label, scenario, "first_seconds")
            compile_time, compile_iqr = sample_stats(comparison, label, scenario, "first_compile_seconds")
            recompile_time, recompile_iqr = sample_stats(comparison, label, scenario, "first_recompile_seconds")
            total_time, total_iqr = sample_stats(comparison, label, scenario, "total_seconds")
            warm_time, warm_iqr = sample_stats(comparison, label, scenario, "warm_seconds")
            warm_compile, warm_compile_iqr = sample_stats(comparison, label, scenario, "warm_compile_seconds")
            warm_recompile, warm_recompile_iqr = sample_stats(comparison, label, scenario, "warm_recompile_seconds")

            baseline_build = first(build_stats(comparison, baseline_label, "build_seconds"))
            baseline_cache = first(build_stats(comparison, baseline_label, "cache_bytes"))
            baseline_import = first(sample_stats(comparison, baseline_label, scenario, "import_seconds"))
            baseline_first = first(sample_stats(comparison, baseline_label, scenario, "first_seconds"))
            baseline_total = first(sample_stats(comparison, baseline_label, scenario, "total_seconds"))

            build_change = "$(signed(delta(build, baseline_build))) s ($(signed(percent_delta(build, baseline_build)))%)"
            cache_change = "$(signed(delta(cache, baseline_cache) / 2.0^20)) MiB ($(signed(percent_delta(cache, baseline_cache)))%)"
            import_change = "$(signed(delta(import_time, baseline_import) * 1e3)) ms ($(signed(percent_delta(import_time, baseline_import)))%)"
            first_change = "$(signed(delta(first_time, baseline_first) * 1e3)) ms ($(signed(percent_delta(first_time, baseline_first)))%)"
            total_change = "$(signed(delta(total_time, baseline_total) * 1e3)) ms ($(signed(percent_delta(total_time, baseline_total)))%)"
            improved, regressed, compared = material_counts(comparison, label, scenario)

            first_compiler = "$(measurement(compile_time, compile_iqr; scale=1e3)) / $(measurement(recompile_time, recompile_iqr; scale=1e3))"
            warm_compiler = "$(measurement(warm_compile, warm_compile_iqr; scale=1e3)) / $(measurement(warm_recompile, warm_recompile_iqr; scale=1e3))"
            println(io, "| $comparison | $label | $scenario | $(measurement(build, build_iqr)) | $build_change | $(measurement(cache, cache_iqr; scale=1 / 2.0^20)) | $cache_change | $(measurement(import_time, import_iqr; scale=1e3)) | $import_change | $(measurement(first_time, first_iqr; scale=1e3)) | $first_change | $first_compiler | $(measurement(total_time, total_iqr; scale=1e3)) | $total_change | $improved better, $regressed worse / $compared | $(measurement(warm_time, warm_iqr; scale=1e3)) | $warm_compiler |")
        end
    end
end
