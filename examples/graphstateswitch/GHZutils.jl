using QuantumSavory
using QuantumSavory.CircuitZoo
using QuantumSavory.ProtocolZoo
using ConcurrentSim
using QuantumOpticsBase
using ResumableFunctions
using NetworkLayout
using Random, StatsBase
using Graphs, GraphRecipes
using DataFrames
using CSV

using QuantumClifford: AbstractStabilizer, Stabilizer, graphstate, sHadamard, sSWAP, stabilizerview, canonicalize!, sCNOT, ghz

const ghzs = [ghz(n) for n in 1:9] # make const in order to not build new every time

"""
    Sets up the entangler protocols at a client.
    
    Args:
        sim: The simulation object time-tracker.
        net: The network object.
        client: The client node to set up the entangler for.
        link_success_prob: The probability of successful entanglement generation.
"""
@resumable function entangle(sim, net, client, link_success_prob)
    @debug "Entangling client $(client)"
    # Set up the entangler protocols at a client
    entangler = EntanglerProt(
        sim=sim, net=net, nodeA=1, slotA=client, nodeB=2, slotB=client,
        success_prob=link_success_prob, rounds=1, attempts=-1, attempt_time=1.0,
        )
    @yield @process entangler()
end