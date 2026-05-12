using QuantumSavory.ResumableFunctions: @resumable, @yield
using QuantumSavory.ConcurrentSim: @process, run

SUITE["quantumchannel"] = BenchmarkGroup(["quantumchannel"])

quantumchannel_bell_state() = (Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2.0)

function prepare_quantumchannel_put(background=nothing)
    sim = Simulation()
    qc = QuantumChannel(sim, 10.0, background)
    reg_src = Register(1)
    reg_ref = Register(1)
    initialize!((reg_src[1], reg_ref[1]), quantumchannel_bell_state())
    return qc, reg_src
end

@resumable function _quantumchannel_sender(sim, qc, source)
    put!(qc, source)
end

@resumable function _quantumchannel_receiver(sim, qc, destination)
    @yield take!(qc, destination)
end

function prepare_quantumchannel_transfer(background=nothing)
    sim = Simulation()
    qc = QuantumChannel(sim, 10.0, background)
    reg_src = Register(1)
    reg_dst = Register(2)
    initialize!((reg_src[1], reg_dst[2]), quantumchannel_bell_state())

    @process _quantumchannel_sender(sim, qc, reg_src[1])
    @process _quantumchannel_receiver(sim, qc, reg_dst[1])

    return sim
end

function prepare_network_quantumchannel_transfer()
    net = RegisterNet([Register(1), Register(2)], quantum_delay=10.0)
    sim = get_time_tracker(net)
    initialize!((net[1, 1], net[2, 2]), quantumchannel_bell_state())

    @process _quantumchannel_sender(sim, qchannel(net, 1 => 2), net[1, 1])
    @process _quantumchannel_receiver(sim, qchannel(net, 1 => 2), net[2, 1])

    return sim
end

SUITE["quantumchannel"]["creation"] = BenchmarkGroup(["creation"])
SUITE["quantumchannel"]["creation"]["plain"] = @benchmarkable QuantumChannel(sim, 10.0) setup=(sim = Simulation()) evals=1
SUITE["quantumchannel"]["creation"]["t1_decay"] = @benchmarkable QuantumChannel(sim, 10.0, T1Decay(0.1)) setup=(sim = Simulation()) evals=1
SUITE["quantumchannel"]["creation"]["t2_dephasing"] = @benchmarkable QuantumChannel(sim, 10.0, T2Dephasing(0.1)) setup=(sim = Simulation()) evals=1

SUITE["quantumchannel"]["put"] = BenchmarkGroup(["put"])
SUITE["quantumchannel"]["put"]["plain"] = @benchmarkable put!(qc, reg_src[1]) setup=((qc, reg_src) = prepare_quantumchannel_put()) evals=1
SUITE["quantumchannel"]["put"]["t1_decay"] = @benchmarkable put!(qc, reg_src[1]) setup=((qc, reg_src) = prepare_quantumchannel_put(T1Decay(0.1))) evals=1
SUITE["quantumchannel"]["put"]["t2_dephasing"] = @benchmarkable put!(qc, reg_src[1]) setup=((qc, reg_src) = prepare_quantumchannel_put(T2Dephasing(0.1))) evals=1

SUITE["quantumchannel"]["transfer"] = BenchmarkGroup(["transfer"])
SUITE["quantumchannel"]["transfer"]["plain"] = @benchmarkable run(sim) setup=(sim = prepare_quantumchannel_transfer()) evals=1
SUITE["quantumchannel"]["transfer"]["t1_decay"] = @benchmarkable run(sim) setup=(sim = prepare_quantumchannel_transfer(T1Decay(0.1))) evals=1
SUITE["quantumchannel"]["transfer"]["t2_dephasing"] = @benchmarkable run(sim) setup=(sim = prepare_quantumchannel_transfer(T2Dephasing(0.1))) evals=1
SUITE["quantumchannel"]["transfer"]["network_qchannel"] = @benchmarkable run(sim) setup=(sim = prepare_network_quantumchannel_transfer()) evals=1
