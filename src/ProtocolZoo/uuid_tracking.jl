"""
$TYPEDSIGNATURES

Generate an integer identifier for a Bell pair in the UUID-based tracker.

The `Tag` storage layer currently supports machine-sized integers, so this uses
positive `Int` values rather than `Base.UUID`.
"""
generate_pair_uuid() = rand(1:typemax(Int))

"""
$TYPEDEF

Live entanglement metadata for the UUID-based tracker.

$TYPEDFIELDS
"""
@kwdef struct EntanglementUUID
    "identifier of the current logical Bell pair"
    uuid::Int
    "the id of the remote node to which we are entangled"
    remote_node::Int
    "the slot in the remote node containing the qubit we are entangled to"
    remote_slot::Int
end
Base.show(io::IO, tag::EntanglementUUID) = print(io, "Entangled UUID $(tag.uuid) to $(tag.remote_node).$(tag.remote_slot)")
Tag(tag::EntanglementUUID) = Tag(EntanglementUUID, tag.uuid, tag.remote_node, tag.remote_slot)

"""
$TYPEDEF

Maps an old UUID to the current live UUID on the same slot. Aliases let late
messages that still refer to an earlier Bell-pair identity find the right
logical qubit after one or more swaps.

$TYPEDFIELDS
"""
@kwdef struct EntanglementUUIDAlias
    "an earlier identifier for this logical Bell-pair half"
    old_uuid::Int
    "the current live UUID on this slot"
    current_uuid::Int
end
Base.show(io::IO, tag::EntanglementUUIDAlias) = print(io, "UUID alias $(tag.old_uuid) -> $(tag.current_uuid)")
Tag(tag::EntanglementUUIDAlias) = Tag(EntanglementUUIDAlias, tag.old_uuid, tag.current_uuid)

"""
$TYPEDEF

Forwarding record kept on a measured-out swapper slot. If a late message arrives
for `uuid`, the tracker forwards it to `target_node.target_slot`, asking that
node to resolve `target_uuid`.

$TYPEDFIELDS
"""
@kwdef struct EntanglementUUIDRoute
    "the old UUID that may still appear in late classical messages"
    uuid::Int
    "the node that now holds the corresponding logical qubit"
    target_node::Int
    "the slot at `target_node` that should handle the forwarded message"
    target_slot::Int
    "the UUID or alias expected at the target slot"
    target_uuid::Int
end
Base.show(io::IO, tag::EntanglementUUIDRoute) = print(io, "Route UUID $(tag.uuid) to $(tag.target_node).$(tag.target_slot) as $(tag.target_uuid)")
Tag(tag::EntanglementUUIDRoute) = Tag(EntanglementUUIDRoute, tag.uuid, tag.target_node, tag.target_slot, tag.target_uuid)

"""
$TYPEDEF

Classical update message from a UUID-based swap. The receiver applies a `Z`
correction when `correction == 2`.

$TYPEDFIELDS
"""
@kwdef struct EntanglementUUIDUpdateX
    "UUID or alias to resolve at the receiving node"
    target_uuid::Int
    "new live UUID after the swap"
    new_uuid::Int
    "new remote node for the receiving qubit"
    new_remote_node::Int
    "new remote slot for the receiving qubit"
    new_remote_slot::Int
    "measurement outcome, where `2` means apply the Pauli correction"
    correction::Int
end
Base.show(io::IO, tag::EntanglementUUIDUpdateX) = print(io, "Update UUID $(tag.target_uuid) to $(tag.new_uuid), entangled to $(tag.new_remote_node).$(tag.new_remote_slot), apply correction Z$(tag.correction)")
Tag(tag::EntanglementUUIDUpdateX) = Tag(EntanglementUUIDUpdateX, tag.target_uuid, tag.new_uuid, tag.new_remote_node, tag.new_remote_slot, tag.correction)

"""
$TYPEDEF

Classical update message from a UUID-based swap. The receiver applies an `X`
correction when `correction == 2`.

$TYPEDFIELDS
"""
@kwdef struct EntanglementUUIDUpdateZ
    "UUID or alias to resolve at the receiving node"
    target_uuid::Int
    "new live UUID after the swap"
    new_uuid::Int
    "new remote node for the receiving qubit"
    new_remote_node::Int
    "new remote slot for the receiving qubit"
    new_remote_slot::Int
    "measurement outcome, where `2` means apply the Pauli correction"
    correction::Int
end
Base.show(io::IO, tag::EntanglementUUIDUpdateZ) = print(io, "Update UUID $(tag.target_uuid) to $(tag.new_uuid), entangled to $(tag.new_remote_node).$(tag.new_remote_slot), apply correction X$(tag.correction)")
Tag(tag::EntanglementUUIDUpdateZ) = Tag(EntanglementUUIDUpdateZ, tag.target_uuid, tag.new_uuid, tag.new_remote_node, tag.new_remote_slot, tag.correction)

"""
$TYPEDEF

Classical deletion message for UUID-tracked entanglement.

$TYPEDFIELDS
"""
@kwdef struct EntanglementUUIDDelete
    "UUID or alias to resolve at the receiving node"
    target_uuid::Int
end
Base.show(io::IO, tag::EntanglementUUIDDelete) = print(io, "Delete UUID $(tag.target_uuid)")
Tag(tag::EntanglementUUIDDelete) = Tag(EntanglementUUIDDelete, tag.target_uuid)

function _uuid_live_on_slot(slot::RegRef, uuid::Int; locked=nothing, assigned=true)
    live = query(slot, EntanglementUUID, uuid, ❓, ❓; locked, assigned)
    !isnothing(live) && return live, uuid
    alias = query(slot, EntanglementUUIDAlias, uuid, ❓; locked, assigned)
    isnothing(alias) && return nothing
    current_uuid = alias.tag[3]
    live = query(slot, EntanglementUUID, current_uuid, ❓, ❓; locked, assigned)
    isnothing(live) && return nothing
    return live, current_uuid
end

function _uuid_live_in_register(reg::Register, uuid::Int; locked=false, assigned=true)
    live = query(reg, EntanglementUUID, uuid, ❓, ❓; locked, assigned)
    !isnothing(live) && return live, uuid

    alias = query(reg, EntanglementUUIDAlias, uuid, ❓; locked, assigned)
    isnothing(alias) && return nothing
    live = query(alias.slot, EntanglementUUID, alias.tag[3], ❓, ❓; locked, assigned)
    isnothing(live) && return nothing
    return live, alias.tag[3]
end

_alias_uuids(slot::RegRef, current_uuid::Int) = [r.tag[2] for r in queryall(slot, EntanglementUUIDAlias, ❓, current_uuid)]

function _delete_uuid_metadata!(slot::RegRef, current_uuid::Int)
    for alias in queryall(slot, EntanglementUUIDAlias, ❓, current_uuid)
        untag!(slot, alias.id)
    end
    live = query(slot, EntanglementUUID, current_uuid, ❓, ❓)
    isnothing(live) || untag!(slot, live.id)
end

function _retag_uuid_live!(slot::RegRef, live, current_uuid::Int, target_uuid::Int, new_uuid::Int, new_remote_node::Int, new_remote_slot::Int)
    aliases = _alias_uuids(slot, current_uuid)
    untag!(slot, live.id)
    for alias in queryall(slot, EntanglementUUIDAlias, ❓, current_uuid)
        untag!(slot, alias.id)
    end
    tag!(slot, EntanglementUUID, new_uuid, new_remote_node, new_remote_slot)
    for old_uuid in unique([aliases; current_uuid; target_uuid])
        old_uuid == new_uuid || tag!(slot, EntanglementUUIDAlias, old_uuid, new_uuid)
    end
end

function _uuid_queryresults(net, node, pred, chooseslots; agelimit=nothing)
    reg = net[node]
    choosefunc = chooseslots isa Vector{Int} ? in(chooseslots) : chooseslots
    return [
        r for r in queryall(reg, EntanglementUUID, ❓, pred, ❓; locked=false, assigned=true)
        if choosefunc(r.slot.idx) && (isnothing(agelimit) || now(get_time_tracker(r.slot)) - r.time < agelimit)
    ]
end

function findswapableuuidqubits(net, node, pred_low, pred_high, choose_low, choose_high, chooseslots; agelimit=nothing)
    low_queryresults = _uuid_queryresults(net, node, pred_low, chooseslots; agelimit)
    high_queryresults = _uuid_queryresults(net, node, pred_high, chooseslots; agelimit)
    (isempty(low_queryresults) || isempty(high_queryresults)) && return nothing
    il = choose_low((qr.tag[3] for qr in low_queryresults))
    ih = choose_high((qr.tag[3] for qr in high_queryresults))
    return (low_queryresults[il], high_queryresults[ih])
end

"""
$TYPEDEF

Generate Bell pairs tagged with [`EntanglementUUID`](@ref).

$TYPEDFIELDS
"""
@kwdef struct EntanglerProtUUID <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex index of node A"""
    nodeA::Int
    """the vertex index of node B"""
    nodeB::Int
    """the state being generated"""
    pairstate::SymQObj = StabilizerState("ZZ XX")
    """success probability of one attempt of entanglement generation"""
    success_prob::Float64 = 0.001
    """duration of single entanglement attempt"""
    attempt_time::Float64 = 0.001
    """fixed busy time immediately before starting entanglement generation attempts"""
    local_busy_time_pre::Float64 = 0.0
    """fixed busy time immediately after a successful attempt"""
    local_busy_time_post::Float64 = 0.0
    """how long to wait before retrying to lock qubits if no qubits are available (`nothing` for waiting on tag changes)"""
    retry_lock_time::Union{Float64,Nothing} = 0.1
    """how many rounds of this protocol to run (`-1` for infinite)"""
    rounds::Int = -1
    """maximum number of attempts to make per round (`-1` for infinite)"""
    attempts::Int = -1
    """slot choice in node A"""
    chooseslotA::Union{Int,Function} = alwaystrue
    """slot choice in node B"""
    chooseslotB::Union{Int,Function} = alwaystrue
    """whether to randomize free-slot selection"""
    randomize::Bool = false
    """whether to lock selected slots during generation"""
    uselock::Bool = true
    """minimum slots to leave free if a pair already exists"""
    margin::Int = 0
    """minimum slots to leave free even before a pair exists"""
    hardmargin::Int = 0
    """function returning a fresh integer UUID"""
    uuid_generator::Function = generate_pair_uuid
end

function EntanglerProtUUID(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int; rate::Union{Nothing,Float64}=nothing, kwargs...)
    if isnothing(rate)
        return EntanglerProtUUID(;sim, net, nodeA, nodeB, kwargs...)
    else
        return EntanglerProtUUID(;sim, net, nodeA, nodeB, kwargs..., success_prob=0.001, attempt_time=0.001/rate)
    end
end

EntanglerProtUUID(net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...) = EntanglerProtUUID(get_time_tracker(net), net, nodeA, nodeB; kwargs...)

@resumable function (prot::EntanglerProtUUID)()
    rounds = prot.rounds
    round = 1
    last_a, last_b = nothing, nothing
    regA = prot.net[prot.nodeA]
    regB = prot.net[prot.nodeB]
    while rounds != 0
        isentangled = !isnothing(query(regA, EntanglementUUID, ❓, prot.nodeB, ❓; assigned=true))
        margin = isentangled ? prot.margin : prot.hardmargin
        (; chooseslotA, chooseslotB, randomize, uselock) = prot
        a_ = findfreeslot(regA; chooseslot=chooseslotA, randomize=randomize, locked=!uselock, margin=margin)
        b_ = findfreeslot(regB; chooseslot=chooseslotB, randomize=randomize, locked=!uselock, margin=margin)

        if isnothing(a_) || isnothing(b_)
            if isnothing(prot.retry_lock_time)
                @yield onchange(regA, Tag) | onchange(regB, Tag)
            else
                @yield timeout(prot.sim, prot.retry_lock_time::Float64)
            end
            continue
        end

        a = a_::RegRef
        b = b_::RegRef
        if uselock
            @yield lock(a) & lock(b)
        end

        @yield timeout(prot.sim, prot.local_busy_time_pre)
        attempts = isone(prot.success_prob) ? 1 : rand(Geometric(prot.success_prob)) + 1
        if prot.attempts == -1 || prot.attempts >= attempts
            @yield timeout(prot.sim, attempts * prot.attempt_time)
            initialize!((a, b), prot.pairstate; time=now(prot.sim))
            @yield timeout(prot.sim, prot.local_busy_time_post)

            uuid = prot.uuid_generator()::Int
            tag!(a, EntanglementUUID, uuid, prot.nodeB, b.idx)
            tag!(b, EntanglementUUID, uuid, prot.nodeA, a.idx)
            last_a = a.idx
            last_b = b.idx
        else
            @yield timeout(prot.sim, prot.attempts * prot.attempt_time)
        end

        if uselock
            unlock(a)
            unlock(b)
        end
        rounds == -1 || (rounds -= 1)
        round += 1
    end
    return prot.nodeA, last_a, prot.nodeB, last_b
end

"""
$TYPEDEF

Perform entanglement swaps using UUID-targeted update messages and forwarding
routes for late messages.

$TYPEDFIELDS
"""
@kwdef struct SwapperProtUUID <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex of the node where swapping is happening"""
    node::Int
    """slot predicate for swappable local slots"""
    chooseslots::Union{Vector{Int},Function} = alwaystrue
    """predicate for the low-side remote node"""
    nodeL::QueryArgs = ❓
    """predicate for the high-side remote node"""
    nodeH::QueryArgs = ❓
    """selector for low-side candidates"""
    chooseL::Function = random_index
    """selector for high-side candidates"""
    chooseH::Function = random_index
    """fixed busy time after the local swap"""
    local_busy_time::Float64 = 0.0
    """how long to wait before retrying if no pair is available (`nothing` for waiting on tag changes)"""
    retry_lock_time::Union{Float64,Nothing} = 0.1
    """how many rounds to run (`-1` for infinite)"""
    rounds::Int = -1
    """oldest selectable qubit age, or `nothing` for no age limit"""
    agelimit::Union{Float64,Nothing} = nothing
    """function returning a fresh integer UUID for the post-swap Bell pair"""
    uuid_generator::Function = generate_pair_uuid
end

SwapperProtUUID(sim::Simulation, net::RegisterNet, node::Int; kwargs...) = SwapperProtUUID(;sim, net, node, kwargs...)
SwapperProtUUID(net::RegisterNet, node::Int; kwargs...) = SwapperProtUUID(get_time_tracker(net), net, node; kwargs...)

function _install_uuid_routes!(slot::RegRef, live_uuid::Int, target_node::Int, target_slot::Int, target_uuid::Int)
    for old_uuid in unique([live_uuid; _alias_uuids(slot, live_uuid)])
        tag!(slot, EntanglementUUIDRoute, old_uuid, target_node, target_slot, target_uuid)
    end
end

@resumable function (prot::SwapperProtUUID)()
    rounds = prot.rounds
    round = 1
    while rounds != 0
        qubit_pair_ = findswapableuuidqubits(prot.net, prot.node, prot.nodeL, prot.nodeH, prot.chooseL, prot.chooseH, prot.chooseslots; agelimit=prot.agelimit)
        if isnothing(qubit_pair_)
            if isnothing(prot.retry_lock_time)
                @yield onchange(prot.net[prot.node], Tag)
            else
                @yield timeout(prot.sim, prot.retry_lock_time::Float64)
            end
            continue
        end

        qubit_pair = qubit_pair_::NTuple{2, QueryOnRegResult}
        q1, selected1 = qubit_pair[1].slot, qubit_pair[1].tag
        q2, selected2 = qubit_pair[2].slot, qubit_pair[2].tag
        @yield lock(q1) & lock(q2)

        current1_ = query(q1, selected1; locked=true, assigned=true)
        current2_ = query(q2, selected2; locked=true, assigned=true)
        if isnothing(current1_) || isnothing(current2_)
            unlock(q1)
            unlock(q2)
            continue
        end

        current1 = current1_::QueryOnRegResult
        current2 = current2_::QueryOnRegResult
        uuid1, node1, slot1 = current1.tag[2], current1.tag[3], current1.tag[4]
        uuid2, node2, slot2 = current2.tag[2], current2.tag[3], current2.tag[4]
        new_uuid = prot.uuid_generator()::Int

        _install_uuid_routes!(q1, uuid1, node2, slot2, uuid2)
        _install_uuid_routes!(q2, uuid2, node1, slot1, uuid1)
        _delete_uuid_metadata!(q1, uuid1)
        _delete_uuid_metadata!(q2, uuid2)

        uptotime!((q1, q2), now(prot.sim))
        xmeas, zmeas = LocalEntanglementSwap()(q1, q2)

        msg1 = Tag(EntanglementUUIDUpdateX, uuid1, new_uuid, node2, slot2, Int(xmeas))
        put!(channel(prot.net, prot.node=>node1; permit_forward=true), msg1)
        msg2 = Tag(EntanglementUUIDUpdateZ, uuid2, new_uuid, node1, slot1, Int(zmeas))
        put!(channel(prot.net, prot.node=>node2; permit_forward=true), msg2)

        @yield timeout(prot.sim, prot.local_busy_time)
        unlock(q1)
        unlock(q2)
        rounds == -1 || (rounds -= 1)
        round += 1
    end
end

"""
$TYPEDEF

Receive and apply UUID-targeted entanglement update/delete messages.

$TYPEDFIELDS
"""
@kwdef struct EntanglementTrackerUUID <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex of the node where the tracker is working"""
    node::Int
end

EntanglementTrackerUUID(net::RegisterNet, node::Int) = EntanglementTrackerUUID(get_time_tracker(net), net, node)

function _forward_uuid_message!(prot, route, tagtype, new_uuid, new_remote_node, new_remote_slot, correction)
    msg = Tag(tagtype, route.tag[5], new_uuid, new_remote_node, new_remote_slot, correction)
    put!(channel(prot.net, prot.node=>route.tag[3]; permit_forward=true), msg)
end

function _handle_uuid_update!(prot, tagtype, updategate)
    return @process _handle_uuid_update_process(prot.sim, prot, tagtype, updategate)
end

@resumable function _handle_uuid_update_process(sim, prot, tagtype, updategate)
    reg = prot.net[prot.node]
    mb = messagebuffer(prot.net, prot.node)
    msg = querydelete!(mb, tagtype, ❓, ❓, ❓, ❓, ❓)
    isnothing(msg) && return false
    target_uuid, new_uuid, new_remote_node, new_remote_slot, correction = msg.tag[2], msg.tag[3], msg.tag[4], msg.tag[5], msg.tag[6]

    live_ = _uuid_live_in_register(reg, target_uuid; locked=false, assigned=true)
    if !isnothing(live_)
        live, current_uuid = live_::Tuple{QueryOnRegResult, Int}
        slot = live.slot
        @yield lock(slot)
        live_ = _uuid_live_on_slot(slot, target_uuid; locked=true, assigned=true)
        if isnothing(live_)
            unlock(slot)
            return true
        end
        live, current_uuid = live_::Tuple{QueryOnRegResult, Int}
        correction == 2 && apply!(slot, updategate)
        _retag_uuid_live!(slot, live, current_uuid, target_uuid, new_uuid, new_remote_node, new_remote_slot)
        unlock(slot)
        return true
    end

    route = query(reg, EntanglementUUIDRoute, target_uuid, ❓, ❓, ❓)
    if !isnothing(route)
        _forward_uuid_message!(prot, route, tagtype, new_uuid, new_remote_node, new_remote_slot, correction)
    else
        @error "EntanglementTrackerUUID @$(prot.node): stale update message=`$msg` is dropped"
    end
    return true
end

function _handle_uuid_delete!(prot)
    return @process _handle_uuid_delete_process(prot.sim, prot)
end

@resumable function _handle_uuid_delete_process(sim, prot)
    reg = prot.net[prot.node]
    mb = messagebuffer(prot.net, prot.node)
    msg = querydelete!(mb, EntanglementUUIDDelete, ❓)
    isnothing(msg) && return false
    target_uuid = msg.tag[2]

    live_ = _uuid_live_in_register(reg, target_uuid; locked=false, assigned=true)
    if !isnothing(live_)
        live, current_uuid = live_::Tuple{QueryOnRegResult, Int}
        slot = live.slot
        @yield lock(slot)
        live_ = _uuid_live_on_slot(slot, target_uuid; locked=true, assigned=true)
        if !isnothing(live_)
            live, current_uuid = live_::Tuple{QueryOnRegResult, Int}
            _delete_uuid_metadata!(slot, current_uuid)
            traceout!(slot)
        end
        unlock(slot)
        return true
    end

    route = query(reg, EntanglementUUIDRoute, target_uuid, ❓, ❓, ❓)
    if !isnothing(route)
        put!(channel(prot.net, prot.node=>route.tag[3]; permit_forward=true), Tag(EntanglementUUIDDelete, route.tag[5]))
    else
        @error "EntanglementTrackerUUID @$(prot.node): stale delete message=`$msg` is dropped"
    end
    return true
end

@resumable function (prot::EntanglementTrackerUUID)()
    mb = messagebuffer(prot.net, prot.node)
    while true
        workwasdone = true
        while workwasdone
            workwasdone = false
            did_update_x = @yield _handle_uuid_update!(prot, EntanglementUUIDUpdateX, Z)
            workwasdone = workwasdone || did_update_x
            did_update_z = @yield _handle_uuid_update!(prot, EntanglementUUIDUpdateZ, X)
            workwasdone = workwasdone || did_update_z
            did_delete = @yield _handle_uuid_delete!(prot)
            workwasdone = workwasdone || did_delete
        end
        @yield onchange(mb)
    end
end

"""
$TYPEDEF

Consume UUID-tracked entanglement between two nodes.

$FIELDS
"""
@kwdef struct EntanglementConsumerUUID <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """first endpoint node"""
    nodeA::Int
    """second endpoint node"""
    nodeB::Int
    """period between queries (`nothing` to wait on tag changes)"""
    period::Union{Float64,Nothing} = 0.1
    """consumption log of time and Bell-pair observables"""
    _log::Vector{@NamedTuple{t::Float64, obs1::Float64, obs2::Float64}} = @NamedTuple{t::Float64, obs1::Float64, obs2::Float64}[]
end

EntanglementConsumerUUID(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...) = EntanglementConsumerUUID(;sim, net, nodeA, nodeB, kwargs...)
EntanglementConsumerUUID(net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...) = EntanglementConsumerUUID(get_time_tracker(net), net, nodeA, nodeB; kwargs...)

permits_virtual_edge(::EntanglementConsumerUUID) = true

@resumable function (prot::EntanglementConsumerUUID)()
    regA = prot.net[prot.nodeA]
    regB = prot.net[prot.nodeB]
    while true
        query1 = query(regA, EntanglementUUID, ❓, prot.nodeB, ❓; locked=false, assigned=true)
        if isnothing(query1)
            isnothing(prot.period) ? (@yield onchange(regA, Tag)) : (@yield timeout(prot.sim, prot.period::Float64))
            continue
        end
        uuid = query1.tag[2]
        query2 = query(regB, EntanglementUUID, uuid, prot.nodeA, query1.slot.idx; locked=false, assigned=true)
        if isnothing(query2)
            isnothing(prot.period) ? (@yield onchange(regB, Tag)) : (@yield timeout(prot.sim, prot.period::Float64))
            continue
        end

        q1, q2 = query1.slot, query2.slot
        @yield lock(q1) & lock(q2)
        query1 = query(q1, EntanglementUUID, uuid, prot.nodeB, q2.idx; locked=true, assigned=true)
        query2 = query(q2, EntanglementUUID, uuid, prot.nodeA, q1.idx; locked=true, assigned=true)
        if isnothing(query1) || isnothing(query2)
            unlock(q1)
            unlock(q2)
            continue
        end

        _delete_uuid_metadata!(q1, uuid)
        _delete_uuid_metadata!(q2, uuid)
        ob1 = observable((q1, q2), Z⊗Z)
        ob2 = observable((q1, q2), X⊗X)
        if isnothing(ob1) || isnothing(ob2)
            traceout!(q1, q2)
            unlock(q1)
            unlock(q2)
            continue
        end
        traceout!(q1, q2)
        push!(prot._log, (now(prot.sim), real(ob1), real(ob2)))
        unlock(q1)
        unlock(q2)
        isnothing(prot.period) || @yield timeout(prot.sim, prot.period::Float64)
    end
end

"""
$TYPEDEF

Cut off stale UUID-tracked entanglement and optionally notify the remote side.

$FIELDS
"""
@kwdef struct CutoffProtUUID <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """node where the protocol runs"""
    node::Int
    """time period between checks (`nothing` to wait on tag changes)"""
    period::Union{Float64,Nothing} = 0.1
    """time after which a slot is emptied"""
    retention_time::Float64 = 5.0
    """whether to send deletion messages"""
    announce::Bool = true
end

CutoffProtUUID(sim::Simulation, net::RegisterNet, node::Int; kwargs...) = CutoffProtUUID(;sim, net, node, kwargs...)
CutoffProtUUID(net::RegisterNet, node::Int; kwargs...) = CutoffProtUUID(get_time_tracker(net), net, node; kwargs...)

@resumable function (prot::CutoffProtUUID)()
    reg = prot.net[prot.node]
    for slot in reg
        @process per_slot_uuid_cutoff(prot.sim, slot, prot)
    end
end

@resumable function per_slot_uuid_cutoff(sim, slot::RegRef, prot::CutoffProtUUID)
    empty_query = false
    while true
        if empty_query
            isnothing(prot.period) ? (@yield onchange(slot, Tag)) : (@yield timeout(prot.sim, prot.period::Float64))
        end
        @yield lock(slot)
        info = query(slot, EntanglementUUID, ❓, ❓, ❓)
        sim_time = now(sim)::Float64
        if isnothing(info) || sim_time - info.time < prot.retention_time
            empty_query = true
            unlock(slot)
            continue
        end

        uuid, remote_node = info.tag[2], info.tag[3]
        _delete_uuid_metadata!(slot, uuid)
        traceout!(slot)
        if prot.announce
            put!(channel(prot.net, prot.node=>remote_node; permit_forward=true), Tag(EntanglementUUIDDelete, uuid))
        end
        unlock(slot)
    end
end
