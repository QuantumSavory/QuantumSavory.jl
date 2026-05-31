SUITE["channels"] = BenchmarkGroup(["channels"])

const CHANNEL_BELL = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2.0)

@resumable function put_slot(env, channel, slot)
    put!(channel, slot)
end

@resumable function take_slot(env, channel, slot)
    @yield take!(channel, slot)
end

function quantum_channel_transfer(; noise = nothing)
    sim = Simulation()
    regA = Register(1)
    regB = Register(2)
    initialize!((regA[1], regB[2]), CHANNEL_BELL)

    channel = isnothing(noise) ? QuantumChannel(sim, 10.0) : QuantumChannel(sim, 10.0, noise)
    @process put_slot(sim, channel, regA[1])
    @process take_slot(sim, channel, regB[1])
    run(sim)

    @assert isassigned(regB, 1)
    @assert !isassigned(regA, 1)
    return regB
end

SUITE["channels"]["quantum_channel"] = BenchmarkGroup(["quantum_channel"])
SUITE["channels"]["quantum_channel"]["ideal_transfer"] =
    @benchmarkable quantum_channel_transfer() evals = 1
SUITE["channels"]["quantum_channel"]["t1_transfer"] =
    @benchmarkable quantum_channel_transfer(noise = T1Decay(0.1)) evals = 1
SUITE["channels"]["quantum_channel"]["t2_transfer"] =
    @benchmarkable quantum_channel_transfer(noise = T2Dephasing(0.1)) evals = 1
