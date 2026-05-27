"""
$TYPEDEF

Metadata message sent by [`GHZProjectionProt`](@ref) after a hub has projected
its local Bell-pair halves into a multipartite GHZ state.

$TYPEDFIELDS
"""
@kwdef struct GHZReady
    "identifier assigned by the hub-side projection protocol"
    ghz_id::Int
    "node that performed the GHZ projection"
    hub_node::Int
    "remote node that owns this member qubit"
    member_node::Int
    "remote memory slot containing this member qubit"
    member_slot::Int
    "one-based position of this member in the GHZ state"
    member_index::Int
    "total number of members in the GHZ state"
    member_count::Int
end
Base.show(io::IO, tag::GHZReady) = print(io, "GHZReady `$(tag.ghz_id)` for member $(tag.member_index)/$(tag.member_count) at $(tag.member_node).$(tag.member_slot)")
Tag(tag::GHZReady) = Tag(GHZReady, tag.ghz_id, tag.hub_node, tag.member_node, tag.member_slot, tag.member_index, tag.member_count)

"""
$TYPEDEF

Tag placed on endpoint qubits by [`GHZReceiverProt`](@ref) once a
[`GHZReady`](@ref) message has arrived.

$TYPEDFIELDS
"""
@kwdef struct GHZMember
    "identifier assigned by the hub-side projection protocol"
    ghz_id::Int
    "node that performed the GHZ projection"
    hub_node::Int
    "one-based position of this member in the GHZ state"
    member_index::Int
    "total number of members in the GHZ state"
    member_count::Int
end
Base.show(io::IO, tag::GHZMember) = print(io, "GHZMember `$(tag.ghz_id)` from hub $(tag.hub_node), member $(tag.member_index)/$(tag.member_count)")
Tag(tag::GHZMember) = Tag(GHZMember, tag.ghz_id, tag.hub_node, tag.member_index, tag.member_count)

const GHZProjectionLogEntry = @NamedTuple{
    t::Float64,
    ghz_id::Int,
    hub_slots::Vector{Int},
    member_nodes::Vector{Int},
    member_slots::Vector{Int},
    x_outcome::Int,
    z_outcomes::Vector{Int},
}

const GHZReceiverLogEntry = @NamedTuple{
    t::Float64,
    ghz_id::Int,
    member_slot::Int,
    member_index::Int,
    member_count::Int,
}

"""
$TYPEDEF

A hub-side protocol that consumes one Bell pair shared with each member node and
projects the remote endpoint qubits into a GHZ state.

The protocol expects the hub register to hold one tagged entangled qubit for
each member in `members`. It performs the local GHZ-basis measurement at the
hub, sends Pauli-frame correction messages to the member nodes through the
existing [`EntanglementTracker`](@ref) message schema, and then announces the
delivered GHZ state with [`GHZReady`](@ref) messages.

Run one [`EntanglementTracker`](@ref) and one [`GHZReceiverProt`](@ref) at each
member node to apply the correction messages and tag the endpoint qubits.

$TYPEDFIELDS
"""
@kwdef struct GHZProjectionProt <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """node that owns the local Bell-pair halves to be measured"""
    hub::Int
    """remote endpoint nodes, in the order used for GHZ member indices"""
    members::Vector{Int}
    """tag type used to find the input Bell pairs"""
    tag::Any = EntanglementCounterpart
    """message tag type used to announce delivered GHZ members (`nothing` disables announcements)"""
    ready_tag::Union{DataType,Nothing} = GHZReady
    """fixed local busy time after the projection measurement"""
    local_busy_time::Float64 = 0.0
    """how long to wait before retrying if input pairs are not ready (`nothing` waits on hub tag changes)"""
    retry_lock_time::Union{Float64,Nothing} = 0.1
    """how many projection rounds to run (`-1` for infinite)"""
    rounds::Int = -1
    """first GHZ identifier to use in the emitted log and ready messages"""
    first_ghz_id::Int = 1
    """stores projection events and measurement outcomes"""
    _log::Vector{GHZProjectionLogEntry} = GHZProjectionLogEntry[]
end

function GHZProjectionProt(sim::Simulation, net::RegisterNet, hub::Int, members::AbstractVector{Int}; kwargs...)
    _validate_ghz_projection_members(hub, members)
    return GHZProjectionProt(;sim, net, hub, members=collect(Int, members), kwargs...)
end

GHZProjectionProt(net::RegisterNet, hub::Int, members::AbstractVector{Int}; kwargs...) =
    GHZProjectionProt(get_time_tracker(net), net, hub, members; kwargs...)

permits_virtual_edge(::GHZProjectionProt) = true

"""
$TYPEDEF

Endpoint-side protocol that receives [`GHZReady`](@ref) messages and tags local
member qubits with [`GHZMember`](@ref).

This protocol is intentionally separate from [`EntanglementTracker`](@ref):
the tracker remains responsible for applying the Pauli corrections sent by
[`GHZProjectionProt`](@ref), while `GHZReceiverProt` records the higher-level
GHZ delivery metadata.

$TYPEDFIELDS
"""
@kwdef struct GHZReceiverProt <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """node that receives GHZ readiness messages"""
    node::Int
    """tag type to add to local GHZ member slots (`nothing` disables tagging)"""
    member_tag::Union{DataType,Nothing} = GHZMember
    """how many ready messages to process (`-1` for infinite)"""
    rounds::Int = -1
    """stores received GHZ delivery metadata"""
    _log::Vector{GHZReceiverLogEntry} = GHZReceiverLogEntry[]
end

function GHZReceiverProt(sim::Simulation, net::RegisterNet, node::Int; kwargs...)
    return GHZReceiverProt(;sim, net, node, kwargs...)
end

GHZReceiverProt(net::RegisterNet, node::Int; kwargs...) = GHZReceiverProt(get_time_tracker(net), net, node; kwargs...)

function _validate_ghz_projection_members(hub::Int, members::AbstractVector{Int})
    length(members) >= 2 || throw(ArgumentError("GHZProjectionProt requires at least two member nodes"))
    hub ∉ members || throw(ArgumentError("GHZProjectionProt hub node cannot also be a member node"))
    length(unique(members)) == length(members) || throw(ArgumentError("GHZProjectionProt member nodes must be unique"))
    return nothing
end

function _find_ghz_projection_inputs(net::RegisterNet, hub::Int, members::Vector{Int}, tag)
    hubreg = net[hub]
    hub_queries = QueryOnRegResult[]
    remote_queries = QueryOnRegResult[]
    seen_hub_slots = Set{Int}()

    for member in members
        hub_query = query(hubreg, tag, member, ❓; locked=false, assigned=true)
        isnothing(hub_query) && return nothing
        hub_slot = hub_query.slot.idx
        hub_slot in seen_hub_slots && return nothing
        push!(seen_hub_slots, hub_slot)

        remote_slot = hub_query.tag[3]
        remote_query = query(net[member][remote_slot], tag, hub, hub_slot; locked=false, assigned=true)
        isnothing(remote_query) && return nothing

        push!(hub_queries, hub_query)
        push!(remote_queries, remote_query)
    end

    return (hub_queries=hub_queries, remote_queries=remote_queries)
end

function _unlock_ghz_projection_slots(hub_slots, remote_slots)
    for slot in Iterators.reverse(remote_slots)
        unlock(slot)
    end
    for slot in Iterators.reverse(hub_slots)
        unlock(slot)
    end
    return nothing
end

function _announce_ghz_ready(prot::GHZProjectionProt, ghz_id::Int, member_nodes::Vector{Int}, member_slots::Vector{Int})
    isnothing(prot.ready_tag) && return nothing
    member_count = length(member_nodes)
    for (member_index, (member_node, member_slot)) in enumerate(zip(member_nodes, member_slots))
        msg = Tag(prot.ready_tag::DataType, ghz_id, prot.hub, member_node, member_slot, member_index, member_count)
        put!(channel(prot.net, prot.hub=>member_node; permit_forward=true), msg)
    end
    return nothing
end

@resumable function (prot::GHZProjectionProt)()
    _validate_ghz_projection_members(prot.hub, prot.members)

    rounds = prot.rounds
    round = 1
    ghz_id = prot.first_ghz_id
    hubreg = prot.net[prot.hub]

    while rounds != 0
        inputs_ = _find_ghz_projection_inputs(prot.net, prot.hub, prot.members, prot.tag)
        if isnothing(inputs_)
            if isnothing(prot.retry_lock_time)
                @debug "$(timestr(prot.sim)) GHZProjectionProt($(compactstr(hubreg))): input pairs not ready. Waiting on hub tag updates."
                @yield onchange(hubreg, Tag)
            else
                @debug "$(timestr(prot.sim)) GHZProjectionProt($(compactstr(hubreg))): input pairs not ready. Waiting a fixed amount of time."
                @yield timeout(prot.sim, prot.retry_lock_time::Float64)
            end
            continue
        end

        inputs = inputs_::NamedTuple{
            (:hub_queries, :remote_queries),
            Tuple{Vector{QueryOnRegResult},Vector{QueryOnRegResult}},
        }
        hub_slots = [query.slot for query in inputs.hub_queries]
        remote_slots = [query.slot for query in inputs.remote_queries]

        for slot in hub_slots
            @yield lock(slot)
        end
        for slot in remote_slots
            @yield lock(slot)
        end

        stale = false
        for i in eachindex(prot.members)
            hub_slot = hub_slots[i]
            remote_slot = remote_slots[i]
            member = prot.members[i]
            hub_current = query(hub_slot, prot.tag, member, remote_slot.idx; locked=true, assigned=true)
            remote_current = query(remote_slot, prot.tag, prot.hub, hub_slot.idx; locked=true, assigned=true)
            if isnothing(hub_current) || isnothing(remote_current)
                stale = true
                break
            end
        end
        if stale
            _unlock_ghz_projection_slots(hub_slots, remote_slots)
            continue
        end

        for i in eachindex(prot.members)
            querydelete!(hub_slots[i], prot.tag, prot.members[i], remote_slots[i].idx)
        end

        uptotime!(vcat(hub_slots, remote_slots), now(prot.sim))

        for i in 2:length(hub_slots)
            apply!([hub_slots[1], hub_slots[i]], CNOT)
        end
        apply!(hub_slots[1], H)

        x_outcome = Int(project_traceout!(hub_slots[1], Z))
        member_nodes = copy(prot.members)
        member_slots = [slot.idx for slot in remote_slots]

        first_msg = Tag(EntanglementUpdateX, prot.hub, hub_slots[1].idx, remote_slots[1].idx, -1, -1, x_outcome)
        put!(channel(prot.net, prot.hub=>member_nodes[1]; permit_forward=true), first_msg)

        z_outcomes = Int[]
        for i in 2:length(hub_slots)
            z_outcome = Int(project_traceout!(hub_slots[i], Z))
            push!(z_outcomes, z_outcome)
            msg = Tag(EntanglementUpdateZ, prot.hub, hub_slots[i].idx, remote_slots[i].idx, -1, -1, z_outcome)
            put!(channel(prot.net, prot.hub=>member_nodes[i]; permit_forward=true), msg)
        end

        _announce_ghz_ready(prot, ghz_id, member_nodes, member_slots)

        push!(prot._log, (
            t=now(prot.sim),
            ghz_id=ghz_id,
            hub_slots=[slot.idx for slot in hub_slots],
            member_nodes=member_nodes,
            member_slots=member_slots,
            x_outcome=x_outcome,
            z_outcomes=z_outcomes,
        ))

        @yield timeout(prot.sim, prot.local_busy_time)
        _unlock_ghz_projection_slots(hub_slots, remote_slots)

        rounds == -1 || (rounds -= 1)
        round += 1
        ghz_id += 1
    end
end

@resumable function (prot::GHZReceiverProt)()
    rounds = prot.rounds
    mb = messagebuffer(prot.net, prot.node)
    reg = prot.net[prot.node]

    while rounds != 0
        msg = querydelete!(mb, GHZReady, ❓, ❓, prot.node, ❓, ❓, ❓)
        if isnothing(msg)
            @yield onchange(mb)
            continue
        end

        (_, ghz_id, hub_node, _, member_slot, member_index, member_count) = msg.tag
        slot = reg[member_slot]
        @yield lock(slot)
        if isassigned(slot)
            if !isnothing(prot.member_tag)
                current = query(slot, prot.member_tag::DataType, ghz_id, hub_node, member_index, member_count; locked=true)
                isnothing(current) && tag!(slot, prot.member_tag::DataType, ghz_id, hub_node, member_index, member_count)
            end
            push!(prot._log, (
                t=now(prot.sim),
                ghz_id=ghz_id,
                member_slot=member_slot,
                member_index=member_index,
                member_count=member_count,
            ))
        end
        unlock(slot)

        rounds == -1 || (rounds -= 1)
    end
end
