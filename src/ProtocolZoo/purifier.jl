"""
$TYPEDEF

A protocol that purifies entanglement between two nodes.
Whenever a pair of entanglement pairs is available, the protocol locks them
and applies the purification circuit.

$TYPEDFIELDS
"""
@kwdef struct PurifierProt{LT} <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex index of node A"""
    nodeA::Int
    """the vertex index of node B"""
    nodeB::Int
    """fixed "busy time" duration immediately before starting the purification"""
    local_busy_time_pre::Float64 = 0.0
    """fixed "busy time" duration immediately after purification"""
    local_busy_time_post::Float64 = 0.0
    """how long to wait before retrying to lock qubits if no qubits are available (`nothing` for queuing up)"""
    retry_lock_time::LT = 0.1
    """how many rounds of this protocol to run (`-1` for infinite)"""
    rounds::Int = -1
    """whether the protocol should find the first available purifyable slots or check for slots randomly from the purifyable slots"""
    randomize::Bool = false
    # """The purification circuit to use. Defaults to `PurifyDEJMPS`."""
    # circuit::AbstractCircuit = PurifyDEJMPS()
end

function PurifierProt(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...)
    return PurifierProt(;sim, net, nodeA, nodeB, kwargs...)
end

@resumable function (prot::PurifierProt)()
    rounds = prot.rounds
    while rounds != 0
        pairs = queryall(prot.net[prot.nodeA], EntanglementCounterpart, prot.nodeB, W; filo=false)
        if length(pairs) < 2    # TODO: should be parametrized to match the circuit requirements
            if isnothing(prot.retry_lock_time)
                @debug "PurifierProt between $(prot.nodeA) and $(prot.nodeB)|round $(round): Failed to find enough entangled pairs \n between waiting for changes to tags..."
                @yield onchange_tag(prot.net[prot.nodeA])
            else
                @debug "PurifierProt between $(prot.nodeA) and $(prot.nodeB)|round $(round): Failed to find enough entangled pairs \n waiting a fixed amount of time..."
                @yield timeout(prot.sim, prot.retry_lock_time)
            end
            continue
        end

        prot.randomize && (pairs = pairs[randperm(length(pairs))])
        (q1L, q1R, id1) = pairs[1].slot, prot.net[prot.nodeB][pairs[1].tag[3]], pairs[1].id
        (q2L, q2R, id2) = pairs[2].slot, prot.net[prot.nodeB][pairs[2].tag[3]], pairs[2].id

        @yield lock(q1L) & lock(q1R) & lock(q2L) & lock(q2R)

        @yield timeout(prot.sim, prot.local_busy_time_pre)
        uptotime!((q1L, q1R, q2L, q2R), now(prot.sim))

        success = PurifyDEJMPS()(q1L, q1R, q2L, q2R)
        untag!(q2L, id2)
        untag!(q2R, query(prot.net[prot.nodeB], EntanglementCounterpart, prot.nodeA, q2L.idx).id)
        if success
            @debug "PurifierProt between $(prot.nodeA) and $(prot.nodeB)|round $(round): Successfully purified entangled pair"
        else
            @debug "PurifierProt between $(prot.nodeA) and $(prot.nodeB)|round $(round): Failed to purify entangled pair \n Discarding entangled pair"
            untag!(q1L, id1)
            untag!(q1R, query(prot.net[prot.nodeB], EntanglementCounterpart, prot.nodeA, q1L.idx).id)
        end
        @yield timeout(prot.sim, prot.local_busy_time_post)

        unlock(q1L)
        unlock(q1R)
        unlock(q2L)
        unlock(q2R)

        rounds -= 1
    end
end