"""
$TYPEDEF

A protocol running at a node,
checking periodically for any qubits in the node that
have remained unused for more than the retention period of the qubit
and emptying such slots.

If coordination messages are exchanged during deletions
(instances of the type [`EntanglementDelete`](@ref)),
then a [`EntanglementTracker`](@ref) protocol needs to also run,
to act on such messages.

$FIELDS
"""
@kwdef struct CutoffProt{LT} <: AbstractProtocol where {LT<:Union{Float64,Nothing}}
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex index of the node on which the protocol is running"""
    node::Int
    """time period between successive queries on the node (`nothing` for queuing up)"""
    period::LT = 0.1
    """time after which a slot is emptied"""
    retention_time::Float64 = 5.0
    """if `true`, synchronization messages are sent after a deletion to the node containing the other entangled qubit"""
    announce::Bool = true
end

function CutoffProt(sim::Simulation, net::RegisterNet, node::Int; kwargs...)
    return CutoffProt(;sim, net, node, kwargs...)
end

@resumable function (prot::CutoffProt)()
    if isnothing(prot.period)
        error("In `CutoffProt` we do not yet support quing up and waiting on register") # TODO
    end
    reg = prot.net[prot.node]
    while true
        for slot in reg # TODO these should be done in parallel, otherwise we will be waiting on each slot, greatly slowing down the cutoffs
            islocked(slot) && continue
            @yield lock(slot)
            info = query(slot, EntanglementCounterpart, ❓, ❓)
            if isnothing(info)
                unlock(slot)
                continue
            end
            if now(prot.sim) - reg.tag_info[info.id][3] > prot.retention_time # TODO this should be part of the query interface, not using non-public implementation details
                untag!(slot, info.id)
                traceout!(slot)
                msg = Tag(EntanglementDelete, prot.node, slot.idx, info.tag[2], info.tag[3])
                tag!(slot, msg)
                (prot.announce) && put!(channel(prot.net, prot.node=>msg[4]; permit_forward=true), msg)
                @debug "CutoffProt @$(prot.node): Send message to $(msg[4]) | message=`$msg` | time=$(now(prot.sim))"
            end

            # TODO the tag deletions below are not necessary when announce=true and EntanglementTracker is running on other nodes. Verify the veracity of that statement, make tests for both cases, and document.

            # delete old history tags
            info = query(slot, EntanglementHistory, ❓, ❓, ❓, ❓, ❓;filo=false) # TODO we should have a warning if `queryall` returns more than one result -- what does it even mean to have multiple history tags here
            if !isnothing(info) && now(prot.sim) - reg.tag_info[info.id][3] > prot.retention_time # TODO this should be part of the query interface, not using non-public implementation details
                untag!(slot, info.id)
            end

            # delete old EntanglementDelete tags
            # TODO Why do we have separate entanglementhistory and entanglementupdate but we have only a single entanglementdelete that serves both roles? We should probably have both be pairs of tags, for consistency and ease of reasoning
            info = query(slot, EntanglementDelete, prot.node, slot.idx , ❓, ❓) # TODO we should have a warning if `queryall` returns more than one result -- what does it even mean to have multiple delete tags here
            if !isnothing(info) && now(prot.sim) - reg.tag_info[info.id][3] > prot.retention_time # TODO this should be part of the query interface, not using non-public implementation details
                untag!(slot, info.id)
            end

            unlock(slot)
        end
        @yield timeout(prot.sim, prot.period)
    end
end
