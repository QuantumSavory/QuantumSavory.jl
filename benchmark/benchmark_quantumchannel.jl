SUITE["quantumchannel"] = BenchmarkGroup(["quantumchannel"])
SUITE["quantumchannel"]["transport"] = BenchmarkGroup(["transport"])

function benchmark_quantum_channel_bell_state()
    return (Z1⊗Z1 + Z2⊗Z2) / sqrt(2.0)
end

@resumable function benchmark_quantum_channel_sender(env, qc, src)
    put!(qc, src)
end

@resumable function benchmark_quantum_channel_receiver(env, qc, dst)
    @yield take!(qc, dst)
end

function prepare_quantum_channel_transport(background)
    regA = Register(1)
    regB = Register(2)
    initialize!((regA[1], regB[2]), benchmark_quantum_channel_bell_state())

    sim = Simulation()
    qc = background === nothing ? QuantumChannel(sim, 10.0) : QuantumChannel(sim, 10.0, background)
    @process benchmark_quantum_channel_sender(sim, qc, regA[1])
    @process benchmark_quantum_channel_receiver(sim, qc, regB[1])
    return sim
end

# Quantum-channel benchmarks cover both bare transport and noisy transport.
SUITE["quantumchannel"]["transport"]["no_background"] = @benchmarkable run(sim) setup=(sim = prepare_quantum_channel_transport(nothing)) evals=1
SUITE["quantumchannel"]["transport"]["t1"] = @benchmarkable run(sim) setup=(sim = prepare_quantum_channel_transport(T1Decay(0.1))) evals=1
SUITE["quantumchannel"]["transport"]["t2"] = @benchmarkable run(sim) setup=(sim = prepare_quantum_channel_transport(T2Dephasing(0.1))) evals=1
