#using QuantumClifford
using QuantumClifford.ECC: CSS, parity_checks
using QuantumClifford: stab_to_gf2, graphstate, Stabilizer, MixedDestabilizer, single_x, single_z, logicalxview, logicalzview

using ResumableFunctions
using ConcurrentSim
using Revise
using Graphs
using QuantumSavory
using QuantumSavory.ProtocolZoo
import QuantumSavory: Tag, swap!

include("../graphstate/graph_preparer.jl")

#using Logging
#global_logger(ConsoleLogger(stderr, Logging.Debug))

# implementing "Measurement-Based Entanglement Distillation and Constant-Rate Quantum Repeaters over Arbitrary Distances"


@kwdef struct GraphToResource <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    nodes::Vector{Int}
    slot::Int
    hadamard_idx::Vector{Int}
    iphase_idx::Vector{Int}
    flips_idx::Vector{Int}
end


@resumable function (prot::GraphToResource)()
    (;sim, net, nodes, slot, hadamard_idx, iphase_idx, flips_idx) = prot

    for i in flips_idx
        apply!(net[nodes[i]][slot], Z)
    end

    for i in iphase_idx
        apply!(net[nodes[i]][slot], sPhase)
    end

    for i in hadamard_idx
        apply!(net[nodes[i]][slot], H)
    end
end


@kwdef struct EntanglerSwap <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    nodeA::Int
    nodeB::Int
    communication_slot::Int
    storage_slot::Int
    pairstate::SymQObj
end


@resumable function (prot::EntanglerSwap)()
    (;sim, net, nodeA, nodeB, communication_slot, storage_slot, pairstate) = prot
    regA = net[nodeA]
    regB = net[nodeB]
    @yield lock(regA[storage_slot]) & lock(regA[communication_slot]) & lock(regB[storage_slot]) & lock(regB[communication_slot])
    entangler = EntanglerProt(sim, net, nodeA, nodeB; pairstate=pairstate, chooseA=communication_slot, chooseB=communication_slot, uselock=false, success_prob=1.0, attempts=-1, rounds=1) # TODO change success_prob
    p = @process entangler()
    @yield p

    # I think we can just do swaps here (assuming storage slots are clean) - check w/ Stefan
    swap!(regA[communication_slot], regA[storage_slot])
    swap!(regB[communication_slot], regB[storage_slot])

    unlock(regA[storage_slot])
    unlock(regA[communication_slot])
    unlock(regB[storage_slot])
    unlock(regB[communication_slot])
end

@kwdef struct Measurements
    node::Int
    measurements_XX::Int64
    measurements_ZZ::Int64
end
Base.show(io::IO, msg::Measurements) = print(io, "XX and ZZ measurements for register $(msg.node): XX=$(bitstring(msg.measurements_XX)), ZZ=$(bitstring(msg.measurements_ZZ))")
Tag(msg::Measurements) = Tag(Measurements, msg.node, msg.measurements_XX, msg.measurements_ZZ)

@kwdef struct BellMeasurements <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    resource_idx::Vector{Int}
    bell_idx::Vector{Int}
    local_chief_idx::Int
    remote_chief_idx::Int
    storage_slot::Int
end

@resumable function (prot::BellMeasurements)()
    (;sim, net, resource_idx, bell_idx, local_chief_idx, remote_chief_idx, storage_slot) = prot

    n = length(bell_idx)

    # not sure if locking is necessary, but maybe will be useful in the future?
    slots = []
    for i in 1:n
        push!(slots, net[resource_idx[i]][storage_slot])
        push!(slots, net[bell_idx[i]][storage_slot])
    end

    @yield reduce(&, [lock(slot) for slot in slots])

    s = []
    t = []
    for i in 1:n
        resource_slot = net[resource_idx[i]][storage_slot]
        bell_slot = net[bell_idx[i]][storage_slot]

        apply!((resource_slot, bell_slot), CNOT)
        mX = project_traceout!(resource_slot, X)
        mZ = project_traceout!(bell_slot, Z)

        push!(s, mX - 1)  # Convert from {1,2} to {0,1}
        push!(t, mZ - 1)
    end

    for slot in slots
        unlock(slot)
    end

    s_int = sum(bit * 2^(i-1) for (i, bit) in enumerate(s))
    t_int = sum(bit * 2^(i-1) for (i, bit) in enumerate(t))

    msg = Measurements(node=local_chief_idx, measurements_XX=s_int, measurements_ZZ=t_int)
    println(msg)

    tag!(net[local_chief_idx][storage_slot], Tag(msg))
    put!(channel(net, local_chief_idx=>remote_chief_idx; permit_forward=true), msg)
end

@kwdef struct PurifiedEntalgementCounterpart
    remote_node::Int
    remote_slot::Int
end
Base.show(io::IO, tag::PurifiedEntalgementCounterpart) = print(io, "Entangled to $(tag.remote_node).$(tag.remote_slot)")
Tag(tag::PurifiedEntalgementCounterpart) = Tag(PurifiedEntalgementCounterpart, tag.remote_node, tag.remote_slot)

@kwdef struct Tracker <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    resource_idx::Vector{Int}
    bell_idx::Vector{Int}
    local_chief_idx::Int
    remote_chief_idx::Int
    H1::Matrix{Int}
    H2::Matrix{Int}
    logxs::Stabilizer
    logzs::Stabilizer
    communication_slot::Int
    storage_slot::Int
    correct::Bool = false
end


@resumable function (prot::Tracker)()
    (;sim, net, resource_idx, bell_idx, local_chief_idx, remote_chief_idx, H1, H2, logxs, logzs, communication_slot, storage_slot, correct) = prot

    n = length(bell_idx)
    k = length(resource_idx) - n
    mb = messagebuffer(net, local_chief_idx)

    while true
        # Wait for local measurement result
        local_tag = query(net[local_chief_idx][storage_slot], Measurements, local_chief_idx, ❓, ❓)

        if isnothing(local_tag)
            @yield onchange_tag(net[local_chief_idx][storage_slot])
            continue
        end

        # Wait for remote measurement result
        msg = query(mb, Measurements, remote_chief_idx, ❓, ❓)
        if isnothing(msg)
            println("Starting message wait at $(now(sim)) with MessageBuffer containing: $(mb.buffer)")
            @yield wait(mb)
            println("Done waiting for message at $(local_chief_idx)")
            continue
        end

        msg_data = querydelete!(mb, Measurements, ❓, ❓, ❓)
        local_measurements_XX = local_tag.tag.data[3]
        local_measurements_ZZ = local_tag.tag.data[4]
        _, (_, remote_node, remote_measurements_XX, remote_measurements_ZZ) = msg_data

        s_int = xor(local_measurements_XX, remote_measurements_XX)
        t_int = xor(local_measurements_ZZ, remote_measurements_ZZ)

        s = [((s_int >> (i-1)) & 1) for i in 1:n]
        t = [((t_int >> (i-1)) & 1) for i in 1:n]
        syndrome = (H1*s + H2*t) .% 2

        if syndrome == [0, 0]
            println("Purification was successful at time $(now(sim))")

            if correct
                println("Correction starting at $(now(sim))")

                logxs_binary = stab_to_gf2(logxs)
                logzs_binary = stab_to_gf2(logzs)
                X_1 = logxs_binary[:, 1:n]
                X_2 = logxs_binary[:, n+1:end]
                Z_1 = logzs_binary[:, 1:n]
                Z_2 = logzs_binary[:, n+1:end]

                # these dont work?
                # r_b = [sum(Z1[i,j] * Z2[i,j] for j in 1:n) for i in 1:k] .% 2
                # r_p = [sum(X1[i,j] * X2[i,j] for j in 1:n) for i in 1:k] .% 2
                r_b = (sum(Z_1 .* Z_2, dims=2)[:]) .% 2
                r_p = (sum(X_1 .* X_2, dims=2)[:]) .% 2

                β = (Z_1*s + Z_2*t + r_b) .% 2
                φ = (X_1*s + X_2*t + r_p) .% 2

                for i in 1:k
                    if β[i] == 1
                        apply!(net[resource_idx[n + i]][storage_slot], X)
                    end
                    if φ[i] == 1
                        apply!(net[resource_idx[n + i]][storage_slot], Z)
                    end
                end

                println("Correction completed at $(now(sim))")
            end

            # Tag purified pairs
            for i in n:n+k-1 # this assumes certain things, so maybe it can be refactored
                tag!(net[local_chief_idx + i][storage_slot], PurifiedEntalgementCounterpart, remote_chief_idx + i, storage_slot)
            end
        else
            println("Purification failed at time $(now(sim)). Syndrome: $syndrome")
            untag!(local_tag.slot, local_tag.id)
            for i in [resource_idx..., bell_idx...]
                traceout!(net[i][communication_slot])
                traceout!(net[i][storage_slot])
            end
        end
    end
end



@resumable function run_protocols(sim, net, resource_state, alice_resource_idx, alice_bell_idx, bob_resource_idx, bob_bell_idx, communication_slot, storage_slot, pairstate, H1, H2, logxs, logzs; rounds=-1)
    n = length(alice_bell_idx)
    @assert n <= 63 "Number of (n=$n) exceeds maximum of 63 bits for Int64 encoding"
    k = length(alice_resource_idx) - n
    alice_chief_idx = alice_resource_idx[1]
    bob_chief_idx = bob_resource_idx[1]
    #add_edge!(net.graph, alice_chief_idx, bob_chief_idx) # for classical communication

    g, hadamard_idx, iphase_idx, flips_idx = graphstate(resource_state)

    graphA = GraphStateConstructor(sim, net, g, alice_resource_idx, communication_slot, storage_slot)
    graphB = GraphStateConstructor(sim, net, g, bob_resource_idx, communication_slot, storage_slot)
    resourceA = GraphToResource(sim, net, alice_resource_idx, storage_slot, hadamard_idx, iphase_idx, flips_idx)
    resourceB = GraphToResource(sim, net, bob_resource_idx, storage_slot, hadamard_idx, iphase_idx, flips_idx)
    alice_bell_meas = BellMeasurements(sim, net, alice_resource_idx, alice_bell_idx, alice_chief_idx, bob_chief_idx, storage_slot)
    bob_bell_meas = BellMeasurements(sim, net, bob_resource_idx, bob_bell_idx, bob_chief_idx, alice_chief_idx, storage_slot)
    alice_tracker = Tracker(sim, net, alice_resource_idx, alice_bell_idx, alice_chief_idx, bob_chief_idx, H1, H2, logxs, logzs, communication_slot, storage_slot, false)
    bob_tracker = Tracker(sim, net, bob_resource_idx, bob_bell_idx, bob_chief_idx, alice_chief_idx, H1, H2, logxs, logzs, communication_slot, storage_slot, true)
    @process alice_tracker()
    @process bob_tracker()

    # # consumer
    # for i in 1:k
    #     purified_consumer = EntanglementConsumer(sim, net, alice_resource_idx[n+i], bob_resource_idx[n+i]; tag=PurifiedEntalgementCounterpart)
    #     @process purified_consumer()
    # end

    round = 0
    while rounds == -1 || round < rounds
        round += 1

        entanglers = []
        for i in 1:n
            entangler = EntanglerSwap(sim, net, alice_bell_idx[i], bob_bell_idx[i], communication_slot, storage_slot, pairstate)
            e = @process entangler()
            push!(entanglers, e)
        end
        g1 = @process graphA()
        g2 = @process graphB()
        @yield reduce(&, (entanglers..., g1, g2))

        println("graph & entangle ", now(sim))
        @yield timeout(sim, 10)

        r1 = @process resourceA()
        r2 = @process resourceB()
        @yield r1 & r2

        println("resource ", now(sim))
        @yield timeout(sim, 10)

        m1 = @process alice_bell_meas()
        m2 = @process bob_bell_meas()
        @yield m1 & m2

        println("measurements ", now(sim))
        @yield timeout(sim, 10)

        # for testing
        for i in 1:k
            purified_consumer = EntanglementConsumer(sim, net, alice_resource_idx[n+i], bob_resource_idx[n+i]; tag=PurifiedEntalgementCounterpart)
            @process purified_consumer()
        end
    end
end

h1 = [1 1 1 1]
h2 = [1 1 1 1]
code = parity_checks(CSS(h1, h2)) # == S"XXXX ZZZZ"
c, n = size(code)
k = n - c
code_binary = stab_to_gf2(code)
H1 = code_binary[:, 1:n]
H2 = code_binary[:, n+1:end]
code_md = MixedDestabilizer(code)
logxs = logicalxview(code_md)
logzs = logicalzview(code_md)

# equation 1
resource_state = vcat(
    hcat(code, zero(Stabilizer, c, k)),
    Stabilizer([l⊗single_x(k,i) for (i,l) in enumerate(logxs)]),
    Stabilizer([l⊗single_z(k,i) for (i,l) in enumerate(logzs)]),
)

pairstate = StabilizerState("ZZ XX")
communication_slot = 1
storage_slot = 2
alice_resource_idx = 1:n+k
alice_bell_idx = n+k+1:2*n+k
bob_resource_idx = 2*n+k+1:3*n+2*k
bob_bell_idx = 3*n+2*k+1:4*n+2*k


registers = [Register(2) for _ in 1:2*(2*n+k)]
net = RegisterNet(registers)
sim = get_time_tracker(net)

@process run_protocols(sim, net, resource_state, alice_resource_idx, alice_bell_idx, bob_resource_idx, bob_bell_idx, communication_slot, storage_slot, pairstate, H1, H2, logxs, logzs, rounds=1)

run(sim, 5)

## graph state checks

g, hadamard_idx, iphase_idx, flips_idx = graphstate(resource_state)
# Alice's graph state
alice_regs = [net[i][storage_slot] for i in alice_resource_idx]
for i in 1:nv(g)
    println(observable(alice_regs, QuantumOpticsBase.Operator(QuantumClifford.Stabilizer(g)[i])))
end

# Bob's graph state
bob_regs = [net[i][storage_slot] for i in bob_resource_idx]
for i in 1:nv(g)
    println(observable(bob_regs, QuantumOpticsBase.Operator(QuantumClifford.Stabilizer(g)[i])))
end

## entangler checks
for i in 1:n
    println(observable([net[alice_bell_idx[i]], net[bob_bell_idx[i]]], [storage_slot, storage_slot], projector(pairstate)))
end

run(sim, 15)

## resource state cheks

# Alice's resource state
for i in 1:length(resource_state)
    println(observable(alice_regs, QuantumOpticsBase.Operator(resource_state[i])))
end

# Bob's resource state
for i in 1:length(resource_state)
    println(observable(bob_regs, QuantumOpticsBase.Operator(resource_state[i])))
end

## entangler checks
for i in 1:n
    println(observable([net[alice_bell_idx[i]], net[bob_bell_idx[i]]], [storage_slot, storage_slot], projector(pairstate)))
end

run(sim, 25)

## purified entanglements checks
for i in 1:k
    println(query(net[alice_resource_idx[n+i]][storage_slot], PurifiedEntalgementCounterpart, ❓, ❓))
    println(query(net[bob_resource_idx[n+i]][storage_slot], PurifiedEntalgementCounterpart, ❓, ❓))
    println(observable([net[alice_resource_idx[n+i]], net[bob_resource_idx[n+i]]], [storage_slot, storage_slot], projector(pairstate)))
end


run(sim, 40)

## consumer
for i in 1:k
    println(query(net[alice_resource_idx[n+i]][storage_slot], PurifiedEntalgementCounterpart, ❓, ❓))
    println(query(net[bob_resource_idx[n+i]][storage_slot], PurifiedEntalgementCounterpart, ❓, ❓))
    println(observable([net[alice_resource_idx[n+i]], net[bob_resource_idx[n+i]]], [storage_slot, storage_slot], projector(pairstate)))
end
