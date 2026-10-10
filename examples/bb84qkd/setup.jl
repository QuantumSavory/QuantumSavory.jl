using QuantumSavory
using Graphs
using ConcurrentSim
using ResumableFunctions
using Random

"""
    BB84Stats

Simulation-level statistics accumulator for the BB84 example.

`times`, `sifted_over_time`, and `qber_over_time` are parallel vectors recording
one data point per sifted round, so that plots can show the key growth and the
running quantum bit error rate (QBER) over simulation time.
"""
mutable struct BB84Stats
    rounds::Int
    sifted::Int
    errors::Int
    times::Vector{Float64}
    sifted_over_time::Vector{Int}
    qber_over_time::Vector{Float64}
end

BB84Stats() = BB84Stats(0, 0, 0, Float64[], Int[], Float64[])

"""The running quantum bit error rate over the sifted key."""
qber(stats::BB84Stats) = stats.sifted == 0 ? NaN : stats.errors / stats.sifted

"""Read a scalar parameter or the current value of a zero-index observable."""
parameter_value(value::Real) = value
parameter_value(value) = value[]

"""Map a basis choice (`false` = Z, `true` = X) and a bit (0 or 1) to a Pauli eigenstate."""
bb84_state(basis::Bool, bit::Int) = basis ? (bit == 0 ? X1 : X2) : (bit == 0 ? Z1 : Z2)

"""
    alice_node(sim, net, rng, rounds, period)

Prepare each signal qubit in a random basis and bit, send it toward Bob through
Eve, and upon Bob's basis announcement reply with the sifting decision and (for
kept rounds) Alice's bit for parameter estimation.

`period` may be a plain number or any zero-index observable (e.g. a Makie
`Observable` driven by a slider), read once per round.
"""
@resumable function alice_node(sim, net, rng, rounds, period)
    mb = messagebuffer(net, 1)
    for round_id in 1:rounds
        @yield timeout(sim, parameter_value(period))
        basis = rand(rng, Bool)
        bit = rand(rng, 0:1)
        initialize!(net[1][1], bb84_state(basis, bit), time=now(sim))
        put!(qchannel(net, 1=>2), net[1][1])
        announce = @yield querydelete_wait!(mb, :bb84_basis, ❓, ❓)
        keep = announce.tag[2] == round_id && announce.tag[3] == Int(basis)
        put!(channel(net, 1=>3; permit_forward=true), Tag(:bb84_sift, round_id, keep ? bit : -1))
    end
end

"""
    eve_node(sim, net, rng, intercept_prob)

Intercept-resend eavesdropper sitting on the Alice→Bob quantum link. Every pulse
is measured in a random basis and reprepared with probability `intercept_prob`,
or forwarded untouched otherwise. `intercept_prob` may be a plain number or a
zero-index observable read once per pulse.
"""
@resumable function eve_node(sim, net, rng, intercept_prob)
    inbound = qchannel(net, 1=>2)
    outbound = qchannel(net, 2=>3)
    while true
        @yield take!(inbound, net[2][1])
        if rand(rng) < parameter_value(intercept_prob)
            basis = rand(rng, Bool)
            outcome = project_traceout!(net[2][1], basis ? σˣ : σᶻ)
            initialize!(net[2][1], bb84_state(basis, outcome == -1 ? 1 : 0), time=now(sim))
        end
        put!(outbound, net[2][1])
    end
end

"""
    bob_node(sim, net, rng, stats)

Measure each incoming pulse in a random basis, announce the basis to Alice over
the (forwarded) classical channel, and update [`BB84Stats`](@ref) once the sifting
reply arrives: a kept round increments `sifted`, a bit mismatch increments
`errors`, and the time series gain one point.
"""
@resumable function bob_node(sim, net, rng, stats)
    inbound = qchannel(net, 2=>3)
    mb = messagebuffer(net, 3)
    round_id = 0
    while true
        @yield take!(inbound, net[3][1])
        round_id += 1
        basis = rand(rng, Bool)
        outcome = project_traceout!(net[3][1], basis ? σˣ : σᶻ)
        bit = outcome == -1 ? 1 : 0
        put!(channel(net, 3=>1; permit_forward=true), Tag(:bb84_basis, round_id, Int(basis)))
        sift = @yield querydelete_wait!(mb, :bb84_sift, ❓, ❓)
        alice_bit = sift.tag[3]
        if alice_bit >= 0
            stats.sifted += 1
            stats.errors += alice_bit != bit
            push!(stats.times, now(sim))
            push!(stats.sifted_over_time, stats.sifted)
            push!(stats.qber_over_time, qber(stats))
        end
        stats.rounds += 1
    end
end

"""
    prepare_simulation(; intercept_prob=0.0, rounds=1000, seed=42, period=1.0,
        quantum_delay=1.0, classical_delay=0.5, representation=CliffordRepr())

Build the Alice–Eve–Bob chain network and start the three protocol processes.
Returns `(sim, net, stats)`.
"""
function prepare_simulation(; intercept_prob=0.0, rounds=1000, seed=42, period=1.0,
        quantum_delay=1.0, classical_delay=0.5, representation=CliffordRepr())
    rng = MersenneTwister(seed)
    alice = Register([Qubit()], [representation], [nothing])
    eve = Register([Qubit()], [representation], [nothing])
    bob = Register([Qubit()], [representation], [nothing])
    net = RegisterNet(path_graph(3), [alice, eve, bob];
        quantum_delay=quantum_delay, classical_delay=classical_delay)
    sim = get_time_tracker(net)
    stats = BB84Stats()
    @process alice_node(sim, net, rng, rounds, period)
    @process eve_node(sim, net, rng, intercept_prob)
    @process bob_node(sim, net, rng, stats)
    return sim, net, stats
end
