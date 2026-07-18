"""
$TYPEDEF

A protocol running at a node,
checking periodically for any qubits in the node that
have remained unused for more than the retention period of the qubit
and emptying such slots.

If coordination messages are exchanged during deletions
(instances of the type `EntanglementDelete`),
then a [`EntanglementTracker`](@ref) protocol needs to also run,
to act on such messages.

$FIELDS
"""
@kwdef struct CutoffProt <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex index of the node on which the protocol is running"""
    node::Int
    """time period between successive queries on the node (`nothing` for queuing up)"""
    period::Union{Float64,Nothing} = 0.1
    """time after which a slot is emptied"""
    retention_time::Float64 = 5.0
    """if `true`, synchronization messages are sent after a deletion to the node containing the other entangled qubit"""
    announce::Bool = true
    """maximum number of delete tags to retain per local slot in FIFO order (`nothing` for unbounded retention)"""
    max_delete_per_slot::Union{Int,Nothing} = 3
end

function CutoffProt(sim::Simulation, net::RegisterNet, node::Int; kwargs...)
    return CutoffProt(;sim, net, node, kwargs...)
end

CutoffProt(net::RegisterNet, node::Int; kwargs...) = CutoffProt(get_time_tracker(net), net, node; kwargs...)

function _enforce_delete_cap!(slot::RegRef, node::Int, max_delete_per_slot::Union{Int,Nothing})
    isnothing(max_delete_per_slot) && return nothing
    max_delete_per_slot < 0 && throw(ArgumentError("max_delete_per_slot must be nonnegative"))
    delete_tags = queryall(slot, EntanglementDelete, ❓, node, slot.idx, ❓, ❓; filo=false)
    for delete_tag in Iterators.take(delete_tags, max(0, length(delete_tags) - max_delete_per_slot))
        untag!(slot, delete_tag.id)
    end
    return nothing
end

@resumable function (prot::CutoffProt)()
    reg = prot.net[prot.node]
    for slot in reg
        @process per_slot_cutoff(prot.sim, slot, prot)
    end
end

@resumable function per_slot_cutoff(sim, slot::RegRef, prot::CutoffProt)
    empty_query = false
    while true
        if empty_query
            if isnothing(prot.period)
                @yield onchange(slot, Tag) # TODO this should be just for the slot, not for the whole register
            else
                @yield timeout(prot.sim, prot.period::Float64)
            end
        end
        @yield lock(slot)
        info = query(slot, EntanglementCounterpart, ❓, ❓, ❓)
        sim_time = now(sim)::Float64
        if isnothing(info) || sim_time - info.time < prot.retention_time
            empty_query = true
            unlock(slot)
            continue
        end

        untag!(slot, info.id)
        traceout!(slot)
        msg = Tag(EntanglementDelete, info.tag[4], prot.node, slot.idx, info.tag[2], info.tag[3])
        tag!(slot, msg)
        # TODO Why do we have separate entanglementhistory and entanglementupdate but we have only a single entanglementdelete that serves both roles? We should probably have both be pairs of tags, for consistency and ease of reasoning
        _enforce_delete_cap!(slot, prot.node, prot.max_delete_per_slot)
        (prot.announce) && put!(channel(prot.net, prot.node=>msg[5]; permit_forward=true), msg)
        @debug(
            "Sent an entanglement deletion",
            _group=LOG_GROUPS.protocol,
            event=:deletion_message_sent,
            protocol_log_context(prot)...,
            src_slot=slot.idx,
            dst_node=msg[5],
            dst_slot=msg[6],
            message_type=:EntanglementDelete,
            pair_id=msg[2],
        )

        unlock(slot)
    end
end
