SUITE["holistic"] = BenchmarkGroup(["holistic"])

const BENCHMARK_REPO_ROOT = pkgdir(QuantumSavory)
const JULIA_CMD = Base.julia_cmd()

function run_cold_import()
    script = "using QuantumSavory; println(\"IMPORT_OK\")"
    cmd = `$JULIA_CMD --project=$(BENCHMARK_REPO_ROOT) -e $script`
    run(cmd)
    return nothing
end

function run_qtcp_tutorial_minirun()
    script = join([
        "include(joinpath($(repr(BENCHMARK_REPO_ROOT)), \"examples\", \"qtcp_tutorial\", \"setup.jl\"))",
        "graph = grid([3])",
        "sim, net = simulation_setup(graph, 4; T2=100.0)",
        "flow = Flow(src=1, dst=3, npairs=1, uuid=1)",
        "put!(net[1], flow)",
        "run(sim, 40.0)",
        "mb_src = messagebuffer(net, 1)",
        "mb_dst = messagebuffer(net, 3)",
        "function count_delivered!(mb, tag_type)",
        "    n = 0",
        "    while !isnothing(querydelete!(mb, tag_type, ❓, ❓, ❓, ❓, ❓, ❓))",
        "        n += 1",
        "    end",
        "    return n",
        "end",
        "@assert count_delivered!(mb_src, QTCPPairBegin) == 1",
        "@assert count_delivered!(mb_dst, QTCPPairEnd) == 1",
        "println(\"QTCP_OK\")",
    ], "; ")
    cmd = `$JULIA_CMD --project=$(BENCHMARK_REPO_ROOT) -e $script`
    run(cmd)
    return nothing
end

# Whole-process benchmarks catch regressions that microbenchmarks miss:
# package load time and a representative end-to-end tutorial execution.
SUITE["holistic"]["cold_import"] = @benchmarkable run_cold_import() evals=1
SUITE["holistic"]["qtcp_tutorial_minirun"] = @benchmarkable run_qtcp_tutorial_minirun() evals=1
