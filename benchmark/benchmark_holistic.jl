SUITE["holistic"] = BenchmarkGroup(["holistic"])

benchmark_repo_root() = pkgdir(QuantumSavory)
julia_cmd() = Base.julia_cmd()

function run_cold_import()
    script = "using QuantumSavory; println(\"IMPORT_OK\")"
    cmd = `$(julia_cmd()) --project=$(benchmark_repo_root()) -e $script`
    run(cmd)
    return nothing
end

function run_qtcp_tutorial_minirun()
    script = join([
        "include(joinpath($(repr(benchmark_repo_root())), \"examples\", \"qtcp_tutorial\", \"setup.jl\"))",
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
    cmd = `$(julia_cmd()) --project=$(benchmark_repo_root()) -e $script`
    run(cmd)
    return nothing
end

# Whole-process benchmarks catch regressions that microbenchmarks miss:
# package load time and a representative end-to-end tutorial execution.
SUITE["holistic"]["cold_import"] = @benchmarkable run_cold_import() evals=1
SUITE["holistic"]["qtcp_tutorial_minirun"] = @benchmarkable run_qtcp_tutorial_minirun() evals=1
