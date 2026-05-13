using QuantumSavory.ResumableFunctions: @resumable, @yield
using QuantumSavory.ConcurrentSim: @process, run

SUITE["load_examples"] = BenchmarkGroup(["load_examples"])

const _load_examples_project = normpath(joinpath(@__DIR__, ".."))

function _run_project_expr(expr::AbstractString)
    cmd = `$(Base.julia_cmd()) --project=$(_load_examples_project) --startup-file=no -e $expr`
    Base.run(pipeline(cmd, stdout=devnull, stderr=devnull))
    return nothing
end

function _run_project_example(script::AbstractString)
    path = normpath(joinpath(_load_examples_project, script))
    _run_project_expr("include($(repr(path)))")
    return nothing
end

@resumable function _manual_superdense_receiver(sim, qc, reg_b)
    @yield take!(qc, reg_b[2])
    apply!((reg_b[2], reg_b[1]), CNOT)
    apply!(reg_b[2], H)
    project_traceout!(reg_b[2], Z)
    project_traceout!(reg_b[1], Z)
end

function run_manual_superdense_coding_example()
    sim = Simulation()
    reg_a = Register(1)
    reg_b = Register(2)
    initialize!((reg_a[1], reg_b[1]), StabilizerState("XX ZZ"))

    qc = QuantumChannel(sim, 10.0)
    @process _manual_superdense_receiver(sim, qc, reg_b)

    apply!(reg_a[1], Z)
    put!(qc, reg_a[1])
    run(sim)

    return nothing
end

SUITE["load_examples"]["loadtime"] = BenchmarkGroup(["loadtime"])
SUITE["load_examples"]["loadtime"]["using_quantumsavory"] =
    @benchmarkable _run_project_expr("using QuantumSavory") samples=1 seconds=1 evals=1
SUITE["load_examples"]["loadtime"]["using_protocolzoo"] =
    @benchmarkable _run_project_expr("using QuantumSavory; using QuantumSavory.ProtocolZoo") samples=1 seconds=1 evals=1

SUITE["load_examples"]["examples"] = BenchmarkGroup(["examples"])
SUITE["load_examples"]["examples"]["manual_superdense_coding"] =
    @benchmarkable run_manual_superdense_coding_example() evals=1
SUITE["load_examples"]["examples"]["qtcp_tutorial_chain_basic"] =
    @benchmarkable _run_project_example(joinpath("examples", "qtcp_tutorial", "1_chain_basic.jl")) samples=1 seconds=1 evals=1
