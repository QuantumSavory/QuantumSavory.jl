SUITE["startup_examples"] = BenchmarkGroup(["startup_examples"])

const _QS_BENCH_REPO_ROOT = normpath(joinpath(@__DIR__, ".."))
const _QS_BENCH_PROJECT = joinpath(_QS_BENCH_REPO_ROOT, "benchmark")
const _QS_EXAMPLES_PROJECT = joinpath(_QS_BENCH_REPO_ROOT, "examples")

function _run_julia_expr(project::AbstractString, expr::AbstractString)
    cmd = `$(Base.julia_cmd()) --startup-file=no --project=$(project) -e $(expr)`
    run(pipeline(cmd; stdout=devnull, stderr=devnull))
end

function _run_julia_script(project::AbstractString, script::AbstractString)
    cmd = `$(Base.julia_cmd()) --startup-file=no --project=$(project) $(script)`
    run(pipeline(cmd; stdout=devnull, stderr=devnull))
end

SUITE["startup_examples"]["import"] = BenchmarkGroup(["import"])
SUITE["startup_examples"]["import"]["using_quantumsavory"] =
    @benchmarkable _run_julia_expr(_QS_BENCH_PROJECT, "using QuantumSavory") evals=1 samples=3
SUITE["startup_examples"]["import"]["using_protocolzoo"] =
    @benchmarkable _run_julia_expr(_QS_BENCH_PROJECT, "using QuantumSavory; using QuantumSavory.ProtocolZoo") evals=1 samples=3

# These scripts are deliberately headless: they avoid GLMakie display/recording
# and provide end-to-end coverage of tutorial examples as user-visible workloads.
SUITE["startup_examples"]["headless_examples"] = BenchmarkGroup(["headless_examples"])
for (label, relpath) in [
    ("qtcp_chain_basic", "examples/qtcp_tutorial/1_chain_basic.jl"),
    ("qtcp_grid_multiflow", "examples/qtcp_tutorial/3_grid_multiflow.jl"),
    ("qtcp_custom_endnode", "examples/qtcp_tutorial/4_custom_endnode.jl"),
]
    script = joinpath(_QS_BENCH_REPO_ROOT, relpath)
    SUITE["startup_examples"]["headless_examples"][label] =
        @benchmarkable _run_julia_script(_QS_EXAMPLES_PROJECT, $script) evals=1 samples=1
end
