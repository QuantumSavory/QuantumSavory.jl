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
    """"""
    nodes::Vector{Int}
    """"""
    slot::Int
    """"""
    hadamard_idx::Vector{Int}
    """"""
    iphase_idx::Vector{Int}
    """"""
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
    """"""
    nodeA::Int
    """"""
    nodeB::Int
    """"""
    communication_slot::Int
    """"""
    storage_slot::Int
    """"""
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


@resumable function run_protocols(sim, net, resource_state, alice_resource_idx, alice_bell_idx, bob_resource_idx, bob_bell_idx, communication_slot, storage_slot, pairstate; rounds=-1)

    g, hadamard_idx, iphase_idx, flips_idx = graphstate(resource_state)

    graphA = GraphStateConstructor(sim, net, g, alice_resource_idx, communication_slot, storage_slot)
    graphB = GraphStateConstructor(sim, net, g, bob_resource_idx, communication_slot, storage_slot)
    resourceA = GraphToResource(sim, net, alice_resource_idx, storage_slot, hadamard_idx, iphase_idx, flips_idx)
    resourceB = GraphToResource(sim, net, bob_resource_idx, storage_slot, hadamard_idx, iphase_idx, flips_idx)

    round = 0
    while rounds == -1 || round < rounds
        round += 1

        entanglers = []
        for i in 1:k
            entangler = EntanglerSwap(sim, net, alice_bell_idx[i], bob_bell_idx[i], communication_slot, storage_slot, pairstate)
            e = @process entangler()
            push!(entanglers, e)
        end
        g1 = @process graphA()
        g2 = @process graphB()
        @yield reduce(&, (entanglers..., g1, g2))
        println("graph & entangle", now(sim))
        @yield timeout(sim, 10)
        r1 = @process resourceA()
        r2 = @process resourceB()
        @yield r1 & r2
        println("resource", now(sim))
        #m1 = @process measure(sim, net, alice_indices[k+1:k+n+1], bob_indices[k+1], storage_slot)
        #m2 = @process measure(sim, net, bob_indices[k+1:k+n+1], alice_indices[k+1], storage_slot)
        #@yield (m1 & m2)
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

@process run_protocols(sim, net, resource_state, alice_resource_idx, alice_bell_idx, bob_resource_idx, bob_bell_idx, communication_slot, storage_slot, pairstate, rounds=1)

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
for i in 1:k
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
for i in 1:k
    println(observable([net[alice_bell_idx[i]], net[bob_bell_idx[i]]], [storage_slot, storage_slot], projector(pairstate)))
end

