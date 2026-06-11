SUITE["examples"] = BenchmarkGroup(["examples"])

const EXAMPLES_DIR = normpath(@__DIR__, "..", "examples")

function run_example_in_fresh_module(relative_path::AbstractString)
    path = joinpath(EXAMPLES_DIR, relative_path)
    mod = Module(:QuantumSavoryBenchmarkExample)
    Core.eval(mod, :(include($path)))
    return nothing
end

function run_example_main_in_fresh_module(relative_path::AbstractString)
    path = joinpath(EXAMPLES_DIR, relative_path)
    mod = Module(:QuantumSavoryBenchmarkExample)
    Core.eval(mod, :(include($path)))
    Core.eval(mod, :(main()))
    return nothing
end

function with_qs_testrun(f)
    old = get(ENV, "QS_TESTRUN", nothing)
    ENV["QS_TESTRUN"] = "true"
    try
        return f()
    finally
        if isnothing(old)
            delete!(ENV, "QS_TESTRUN")
        else
            ENV["QS_TESTRUN"] = old
        end
    end
end

function example_qtcp_chain_basic()
    run_example_in_fresh_module(joinpath("qtcp_tutorial", "1_chain_basic.jl"))
end

function example_qtcp_custom_endnode()
    run_example_main_in_fresh_module(joinpath("qtcp_tutorial", "4_custom_endnode.jl"))
end

function example_purification_mbqc()
    with_qs_testrun() do
        run_example_in_fresh_module(joinpath("purificationMBQC", "full_purification_example.jl"))
    end
end

# These are holistic benchmarks for representative non-plotting examples. They
# intentionally use one sample/eval because each include runs top-level setup and
# a complete simulation, mirroring how examples are exercised by test/examples.
SUITE["examples"]["qtcp_chain_basic"] = @benchmarkable example_qtcp_chain_basic() evals=1 samples=1
SUITE["examples"]["qtcp_custom_endnode"] = @benchmarkable example_qtcp_custom_endnode() evals=1 samples=1
SUITE["examples"]["purification_mbqc"] = @benchmarkable example_purification_mbqc() evals=1 samples=1
