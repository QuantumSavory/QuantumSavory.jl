include("setup.jl")

const IS_TEST_RUN = get(ENV, "QS_TESTRUN", "false") == "true"

retention_values = IS_TEST_RUN ? [2.0, 5.0] : [1.0, 2.0, 5.0, 10.0]
duration = IS_TEST_RUN ? 12.0 : 60.0

results = [
    run_cutoff_point(;
        retention_time = retention,
        agelimit_buffer = min(0.5, retention / 4),
        duration,
        random_seed = 100 + i,
    )
    for (i, retention) in enumerate(retention_values)
]

println("retention_time  delivered  mean_ZZ  mean_XX  mean_interval")
for row in results
    println(
        lpad(string(row.retention_time), 14), "  ",
        lpad(string(row.delivered), 9), "  ",
        lpad(isnan(row.mean_zz) ? "NaN" : string(round(row.mean_zz; digits = 3)), 7), "  ",
        lpad(isnan(row.mean_xx) ? "NaN" : string(round(row.mean_xx; digits = 3)), 7), "  ",
        lpad(isnan(row.mean_interval) ? "NaN" : string(round(row.mean_interval; digits = 3)), 13),
    )
end
