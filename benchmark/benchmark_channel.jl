SUITE["channel"] = BenchmarkGroup(["channel"])

# Channel creation benchmarks
SUITE["channel"]["creation"] = BenchmarkGroup(["creation"])
SUITE["channel"]["creation"]["default"] = @benchmarkable begin
    sim = Simulation()
    qc = QuantumChannel(sim, 10.0)
end
SUITE["channel"]["creation"]["with_background"] = @benchmarkable begin
    sim = Simulation()
    qc = QuantumChannel(sim, 10.0, T2Dephasing(1.0))
end

# Channel put!/take! benchmarks - using top-level resumable functions
@resumable function _ch_sender(env, qc, regA)
    put!(qc, regA[1])
end

@resumable function _ch_receiver(env, qc, regB)
    @yield take!(qc, regB[1])
end

function _run_channel_put_take(delay, background=nothing)
    sim = Simulation()
    regA = Register(1)
    regB = Register(1)
    initialize!(regA[1], Z1)
    qc = if background === nothing
        QuantumChannel(sim, delay)
    else
        QuantumChannel(sim, delay, background)
    end
    @process _ch_sender(sim, qc, regA)
    @process _ch_receiver(sim, qc, regB)
    run(sim)
end

SUITE["channel"]["put_take"] = BenchmarkGroup(["put_take"])
SUITE["channel"]["put_take"]["basic"] = @benchmarkable _run_channel_put_take(5.0)
SUITE["channel"]["put_take"]["with_background"] = @benchmarkable _run_channel_put_take(5.0, T2Dephasing(1.0))

for delay in [1.0, 10.0, 100.0]
    d = delay
    SUITE["channel"]["put_take"]["delay_$(d)"] = @benchmarkable _run_channel_put_take($d)
end
