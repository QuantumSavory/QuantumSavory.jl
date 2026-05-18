SUITE["loadtime"] = BenchmarkGroup(["loadtime"])

const BENCHMARK_PROJECT = @__DIR__

function run_quantumsavory_import()
    run(`$(Base.julia_cmd()) --project=$(BENCHMARK_PROJECT) -e "using QuantumSavory"`)
    return nothing
end

# Measure package load time in a fresh Julia process. This complements the
# in-process API microbenchmarks and tracks the user-facing cost of importing
# QuantumSavory from the benchmark environment.
SUITE["loadtime"]["quantumsavory_import"] =
    @benchmarkable run_quantumsavory_import() evals=1 samples=1
