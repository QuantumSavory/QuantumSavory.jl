"""
$TYPEDEF

A tag that stores a UUID assigned to a Bell pair. This UUID is used by the UUID-based entanglement
tracking protocol to identify and track pairs throughout their lifetime, including across swaps.

$TYPEDFIELDS
"""
@kwdef struct EntanglementUUID
    """The UUID assigned to this Bell pair (stored as `Int` for Tag compatibility)"""
    uuid::Int
    """The remote node to which we are entangled"""
    remote_node::Int
    """The remote slot to which we are entangled"""
    remote_slot::Int
end

Base.show(io::IO, tag::EntanglementUUID) = print(
    io,
    "UUID $(string(tag.uuid, base=16)) entangled to $(tag.remote_node).$(tag.remote_slot)",
)
Tag(tag::EntanglementUUID) =
    Tag(EntanglementUUID, tag.uuid, tag.remote_node, tag.remote_slot)

"""
$TYPEDEF

A message tag that arrives after a remote node performs an entanglement swap.
It updates the entanglement information and includes any necessary Pauli corrections.

Unlike the old EntanglementUpdate tags, this uses a UUID to identify the pair that was swapped.

$TYPEDFIELDS
"""
@kwdef struct EntanglementUpdateUUID
    """The UUID of the pair being updated (stored as `Int` for Tag compatibility)"""
    uuid::Int
    """The node that performed the swap"""
    swap_node::Int
    """The qubit measurement outcome for X basis (0 or 1)"""
    x_meas::Int
    """The qubit measurement outcome for Z basis (0 or 1)"""
    z_meas::Int
    """The new remote node after the swap"""
    new_remote_node::Int
    """The new remote slot after the swap"""
    new_remote_slot::Int
end

Base.show(io::IO, tag::EntanglementUpdateUUID) = print(
    io,
    "Update UUID $(string(tag.uuid, base=16)): X_meas=$(tag.x_meas) Z_meas=$(tag.z_meas), new counterpart $(tag.new_remote_node).$(tag.new_remote_slot)",
)
Tag(tag::EntanglementUpdateUUID) = Tag(
    EntanglementUpdateUUID,
    tag.uuid,
    tag.swap_node,
    tag.x_meas,
    tag.z_meas,
    tag.new_remote_node,
    tag.new_remote_slot,
)

"""
$TYPEDEF

A message tag that arrives when a remote node deletes an entangled qubit.
Identifies the pair by UUID.

$TYPEDFIELDS
"""
@kwdef struct EntanglementDeleteUUID
    """The UUID of the pair being deleted (stored as `Int` for Tag compatibility)"""
    uuid::Int
    """The node that is deleting the qubit"""
    delete_node::Int
    """The slot being deleted at the delete_node"""
    delete_slot::Int
end

Base.show(io::IO, tag::EntanglementDeleteUUID) = print(
    io,
    "Delete UUID $(string(tag.uuid, base=16)): deleted at $(tag.delete_node).$(tag.delete_slot)",
)
Tag(tag::EntanglementDeleteUUID) =
    Tag(EntanglementDeleteUUID, tag.uuid, tag.delete_node, tag.delete_slot)

"""
    generate_pair_uuid()::Int

Generate a new UUID for an entangled pair (stored as `Int` to integrate with Tag system).
"""
function generate_pair_uuid()::Int
    return rand(Int)
end

"""$TYPEDEF

A protocol that generates entanglement between two nodes using UUID-based tracking.

Whenever a pair of empty slots is available, the protocol locks them and starts probabilistic
attempts to establish entanglement. Unlike [`EntanglerProt`](@ref), this version uses UUID-based
tracking which simplifies state management and is more scalable for large networks.

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
    """the state being generated (supports symbolic, numeric, noisy, and pure)"""
    pairstate::SymQObj = StabilizerState("ZZ XX")
    """success probability of one attempt of entanglement generation"""
    success_prob::Float64 = 0.001
    """duration of single entanglement attempt"""
    attempt_time::Float64 = 0.001
    """fixed "busy time" duration immediately before starting entanglement generation attempts"""
    local_busy_time_pre::Float64 = 0.0
    """fixed "busy time" duration immediately after the a successful entanglement generation attempt"""
    local_busy_time_post::Float64 = 0.0
    """how long to wait before retrying to lock qubits if no qubits are available (`nothing` for queuing up)"""
    retry_lock_time::Union{Float64,Nothing} = 0.1
    """how many rounds of this protocol to run (`-1` for infinite)"""
    rounds::Int = -1
    """maximum number of attempts to make per round (`-1` for infinite)"""
    attempts::Int = -1
    """function `Int->Bool` or an integer slot number, specifying the slot to take among available free slots in node A"""
    chooseslotA::Union{Int,Function} = alwaystrue
    """function `Int->Bool` or an integer slot number, specifying the slot to take among available free slots in node B"""
    chooseslotB::Union{Int,Function} = alwaystrue
    """whether the protocol should find the first available free slots in the nodes to be entangled or check for free slots randomly from the available slots"""
    randomize::Bool = false
    """whether the protocol should look for unlocked slots to entangle and lock them during the protocol"""
    uselock::Bool = true
    """Repeated rounds of this protocol may lead to monopolizing all slots of a pair of registers, starving or deadlocking other protocols. This field can be used to always leave a minimum number of slots free if there already exists entanglement between the current pair of nodes."""
    margin::Int = 0
    """Like `margin`, but it is enforced even when no entanglement has been established yet. Usually smaller than `margin`."""
    hardmargin::Int = 0
end

"""Convenience constructor for specifying `rate` of generation instead of success probability and time"""
function EntanglerProtUUID(
    sim::Simulation,
    net::RegisterNet,
    nodeA::Int,
    nodeB::Int;
    rate::Union{Nothing,Float64} = nothing,
    kwargs...,
)
    if isnothing(rate)
        return EntanglerProtUUID(; sim, net, nodeA, nodeB, kwargs...)
    else
        return EntanglerProtUUID(;
            sim,
            net,
            nodeA,
            nodeB,
            kwargs...,
            success_prob = 0.001,
            attempt_time = 0.001/rate,
        )
    end
end

EntanglerProtUUID(net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...) =
    EntanglerProtUUID(get_time_tracker(net), net, nodeA, nodeB; kwargs...)

@resumable function (prot::EntanglerProtUUID)()
    rounds = prot.rounds
    round = 1
    last_a, last_b = nothing, nothing
    regA = prot.net[prot.nodeA]
    regB = prot.net[prot.nodeB]
    while rounds != 0
        isentangled =
            !isnothing(query(regA, EntanglementUUID, ❓, prot.nodeB, ❓; assigned = true))
        margin = isentangled ? prot.margin : prot.hardmargin
        (; chooseslotA, chooseslotB, randomize, uselock) = prot
        a_ = findfreeslot(
            regA;
            chooseslot = chooseslotA,
            randomize = randomize,
            locked = !uselock,
            margin = margin,
        )
        b_ = findfreeslot(
            regB;
            chooseslot = chooseslotB,
            randomize = randomize,
            locked = !uselock,
            margin = margin,
        )

        if isnothing(a_) || isnothing(b_)
            if isnothing(prot.retry_lock_time)
                @debug "$(timestr(prot.sim)) EntanglerProtUUID($(compactstr(regA)), $(compactstr(regB))), round $(round): Failed to find free slots, waiting for changes to tags..."
                @yield onchange(regA, Tag) | onchange(regB, Tag)
            else
                @debug "$(timestr(prot.sim)) EntanglerProtUUID($(compactstr(regA)), $(compactstr(regB))), round $(round): Failed to find free slots, waiting a fixed amount of time..."
                @yield timeout(prot.sim, prot.retry_lock_time::Float64)
            end
            continue
        end
        # we are now certain that a_ and b_ are not nothing. The compiler is not smart enough to figure this out
        # on its own, so we need to tell it explicitly. A new variable name is needed due to @resumable.
        a = a_::RegRef
        b = b_::RegRef

        if uselock
            @yield lock(a) & lock(b) # this yield is expected to return immediately
        end

        @yield timeout(prot.sim, prot.local_busy_time_pre)
        attempts = if isone(prot.success_prob)
            1
        else
            rand(Geometric(prot.success_prob))+1
        end
        if prot.attempts == -1 || prot.attempts >= attempts
            @yield timeout(prot.sim, attempts * prot.attempt_time)
            initialize!((a, b), prot.pairstate; time = now(prot.sim))
            @yield timeout(prot.sim, prot.local_busy_time_post)

            # Generate and assign UUIDs
            uuid = generate_pair_uuid()
            tag!(a, EntanglementUUID, uuid, prot.nodeB, b.idx)
            tag!(b, EntanglementUUID, uuid, prot.nodeA, a.idx)
            last_a = a.idx
            last_b = b.idx

            @debug "$(timestr(prot.sim)) EntanglerProtUUID($(compactstr(regA)), $(compactstr(regB))), round $(round): Entangled .$(a.idx) and .$(b.idx) with UUID $(string(uuid, base=16))"
        else
            @yield timeout(prot.sim, prot.attempts * prot.attempt_time)
            @debug "$(timestr(prot.sim)) EntanglerProtUUID($(compactstr(regA)), $(compactstr(regB))), round $(round): Performed the maximum number of attempts and gave up"
        end
        if uselock
            unlock(a)
            unlock(b)
        end
        rounds==-1 || (rounds -= 1)
        round += 1
    end
    return prot.nodeA, last_a, prot.nodeB, last_b
end

"""
$TYPEDEF

A protocol running at a given node that tracks entanglement using UUIDs assigned to each Bell pair.

This is an alternative implementation to [`EntanglementTracker`](@ref) that uses UUIDs to identify
pairs instead of maintaining detailed history. This approach is simpler and more scalable:
- Each pair is assigned a unique UUID when created
- Swaps are tracked by updating the UUID's remote endpoint
- Messages reference the UUID instead of node/slot combinations
- No need for history tags to handle forwarded messages

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

EntanglementTrackerUUID(net::RegisterNet, node::Int) =
    EntanglementTrackerUUID(get_time_tracker(net), net, node)

@resumable function (prot::EntanglementTrackerUUID)()
    nodereg = prot.net[prot.node]
    mb = messagebuffer(prot.net, prot.node)

    while true
        workwasdone = true
        while workwasdone
            workwasdone = false

            # Process EntanglementUpdateUUID messages (pair was swapped)
            msg = querydelete!(mb, EntanglementUpdateUUID, ❓, ❓, ❓, ❓, ❓, ❓)
            if !isnothing(msg)
                (
                    src,
                    (_, uuid, swap_node, x_meas, z_meas, new_remote_node, new_remote_slot),
                ) = msg
                workwasdone = true

                @debug "EntanglementTrackerUUID @$(prot.node): Received update for UUID $(string(uuid, base=16)) from swap at $(swap_node) | time=$(now(prot.sim))"

                # Find the local slot with this UUID
                slot_with_uuid = nothing
                for (idx, slot) in enumerate(nodereg)
                    counterpart = query(slot, EntanglementUUID, uuid, ❓, ❓)
                    if !isnothing(counterpart)
                        slot_with_uuid = slot
                        break
                    end
                end

                if !isnothing(slot_with_uuid)
                    @yield lock(slot_with_uuid)

                    if isassigned(slot_with_uuid)
                        # Remove old EntanglementUUID tag
                        untag!(
                            slot_with_uuid,
                            query(slot_with_uuid, EntanglementUUID, uuid, ❓, ❓).id,
                        )

                        # Apply corrections based on measurements
                        # If x_meas == 1, we need to apply Z correction
                        if x_meas == 1
                            apply!(slot_with_uuid, Z)
                        end
                        # If z_meas == 1, we need to apply X correction
                        if z_meas == 1
                            apply!(slot_with_uuid, X)
                        end

                        # Update the entanglement information
                        if new_remote_node != -1
                            tag!(
                                slot_with_uuid,
                                EntanglementUUID,
                                uuid,
                                new_remote_node,
                                new_remote_slot,
                            )
                        end
                    else
                        @warn "EntanglementTrackerUUID @$(prot.node): Received update for UUID $(string(uuid, base=16)) but the slot is unassigned"
                    end

                    unlock(slot_with_uuid)
                    continue
                end

                # If we can't find the local slot, something went wrong
                @warn "EntanglementTrackerUUID @$(prot.node): Received update for UUID $(string(uuid, base=16)) but couldn't find corresponding local slot"
                continue
            end

            # Process EntanglementDeleteUUID messages (remote qubit was deleted)
            msg = querydelete!(mb, EntanglementDeleteUUID, ❓, ❓, ❓)
            if !isnothing(msg)
                (src, (_, uuid, delete_node, delete_slot)) = msg
                workwasdone = true

                @debug "EntanglementTrackerUUID @$(prot.node): Received delete for UUID $(string(uuid, base=16)) from $(delete_node) | time=$(now(prot.sim))"

                # Find the local slot with this UUID
                slot_with_uuid = nothing
                for (idx, slot) in enumerate(nodereg)
                    counterpart = query(slot, EntanglementUUID, uuid, ❓, ❓)
                    if !isnothing(counterpart)
                        slot_with_uuid = slot
                        break
                    end
                end

                if !isnothing(slot_with_uuid)
                    @yield lock(slot_with_uuid)

                    # Trace out the qubit
                    traceout!(slot_with_uuid)

                    unlock(slot_with_uuid)
                    continue
                end

                # If we can't find the local slot, something went wrong (but this might be ok if qubit was already deleted)
                @debug "EntanglementTrackerUUID @$(prot.node): Received delete for UUID $(string(uuid, base=16)) but couldn't find corresponding local slot"
                continue
            end
        end

        @debug "EntanglementTrackerUUID @$(prot.node): Waiting for messages at $(now(prot.sim))"
        @yield onchange(mb)
    end
end

"""
$TYPEDEF

A protocol running at a given node that finds swappable entangled pairs and performs the swap,
using UUID-based tracking.

$TYPEDFIELDS
"""
@kwdef struct SwapperProtUUID <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex of the node where swapping is happening"""
    node::Int
    """function `Int->Bool` or a vector of allowed slot indices, specifying the slots to take among swappable slots in the node"""
    chooseslots::Union{Vector{Int},Function} = alwaystrue
    """the vertex of one of the remote nodes for the swap"""
    nodeL::QueryArgs = ❓
    """the vertex of the other remote node for the swap"""
    nodeH::QueryArgs = ❓
    """function to choose among low node candidates"""
    chooseL::Function = random_index
    """function to choose among high node candidates"""
    chooseH::Function = random_index
    """fixed "busy time" duration immediately before starting swap"""
    local_busy_time::Float64 = 0.0
    """how long to wait before retrying to lock qubits if no qubits are available"""
    retry_lock_time::Union{Float64,Nothing} = 0.1
    """how many rounds of this protocol to run (`-1` for infinite)"""
    rounds::Int = -1
    """what is the oldest a qubit should be to be picked for a swap"""
    agelimit::Union{Float64,Nothing} = nothing
end

function SwapperProtUUID(sim::Simulation, net::RegisterNet, node::Int; kwargs...)
    return SwapperProtUUID(; sim, net, node, kwargs...)
end

SwapperProtUUID(net::RegisterNet, node::Int; kwargs...) =
    SwapperProtUUID(get_time_tracker(net), net, node; kwargs...)

function findswapablequbits_uuid(
    net,
    node,
    pred_low,
    pred_high,
    choose_low,
    choose_high,
    chooseslots;
    agelimit = nothing,
)
    reg = net[node]
    low_queryresults = [
        n for n in queryall(
            reg,
            EntanglementUUID,
            ❓,
            pred_low,
            ❓;
            locked = false,
            assigned = true,
        ) if isnothing(agelimit) || !isolderthan(n.slot, agelimit)
    ]
    high_queryresults = [
        n for n in queryall(
            reg,
            EntanglementUUID,
            ❓,
            pred_high,
            ❓;
            locked = false,
            assigned = true,
        ) if isnothing(agelimit) || !isolderthan(n.slot, agelimit)
    ]

    choosefunc = chooseslots isa Vector{Int} ? in(chooseslots) : chooseslots
    low_queryresults = [qr for qr in low_queryresults if choosefunc(qr.slot.idx)]
    high_queryresults = [qr for qr in high_queryresults if choosefunc(qr.slot.idx)]

    (isempty(low_queryresults) || isempty(high_queryresults)) && return nothing
    il = choose_low((qr.tag[2] for qr in low_queryresults))  # Extract remote_node
    ih = choose_high((qr.tag[2] for qr in high_queryresults))
    return (low_queryresults[il], high_queryresults[ih])
end

@resumable function (prot::SwapperProtUUID)()
    rounds = prot.rounds
    round = 1
    while rounds != 0
        qubit_pair_ = findswapablequbits_uuid(
            prot.net,
            prot.node,
            prot.nodeL,
            prot.nodeH,
            prot.chooseL,
            prot.chooseH,
            prot.chooseslots;
            agelimit = prot.agelimit,
        )
        if isnothing(qubit_pair_)
            if isnothing(prot.retry_lock_time)
                @debug "SwapperProtUUID: no swappable qubits found. Waiting for tag change..."
                @yield onchange(prot.net[prot.node], Tag)
            else
                @debug "SwapperProtUUID: no swappable qubits found. Waiting a fixed amount of time..."
                @yield timeout(prot.sim, prot.retry_lock_time::Float64)
            end
            continue
        end

        qubit_pair = qubit_pair_::NTuple{
            2,
            Base.NamedTuple{(:slot, :id, :tag),Base.Tuple{RegRef,Int128,Tag}},
        }

        (q1, id1, tag1) = qubit_pair[1].slot, qubit_pair[1].id, qubit_pair[1].tag
        (q2, id2, tag2) = qubit_pair[2].slot, qubit_pair[2].id, qubit_pair[2].tag

        @yield lock(q1) & lock(q2)

        # Extract UUID and remote node/slot info from tags
        uuid1 = tag1[2]
        remote_node1 = tag1[3]
        remote_slot1 = tag1[4]

        uuid2 = tag2[2]
        remote_node2 = tag2[3]
        remote_slot2 = tag2[4]

        # Remove old tags
        untag!(q1, id1)
        untag!(q2, id2)

        # Perform the swap
        uptotime!((q1, q2), now(prot.sim))
        swapcircuit = LocalEntanglementSwap()
        xmeas, zmeas = swapcircuit(q1, q2)

        # Tag with new UUIDs
        tag!(q1, EntanglementUUID, uuid2, remote_node2, remote_slot2)
        tag!(q2, EntanglementUUID, uuid1, remote_node1, remote_slot1)

        # Send update messages to remote nodes
        # Node 1 needs to know that UUID1 now points to remote_node2.remote_slot2
        msg1 = Tag(
            EntanglementUpdateUUID,
            uuid1,
            prot.node,
            Int(xmeas),
            Int(zmeas),
            remote_node2,
            remote_slot2,
        )
        put!(channel(prot.net, prot.node=>remote_node1; permit_forward = true), msg1)
        @debug "SwapperProtUUID @$(prot.node)|round $(round): Send update to $(remote_node1) for UUID $(string(uuid1, base=16))"

        # Node 2 needs to know that UUID2 now points to remote_node1.remote_slot1
        msg2 = Tag(
            EntanglementUpdateUUID,
            uuid2,
            prot.node,
            Int(zmeas),
            Int(xmeas),
            remote_node1,
            remote_slot1,
        )
        put!(channel(prot.net, prot.node=>remote_node2; permit_forward = true), msg2)
        @debug "SwapperProtUUID @$(prot.node)|round $(round): Send update to $(remote_node2) for UUID $(string(uuid2, base=16))"

        @yield timeout(prot.sim, prot.local_busy_time)
        unlock(q1)
        unlock(q2)
        rounds==-1 || (rounds -= 1)
        round += 1
    end
end

"""
$TYPEDEF

A protocol running at a node that deletes qubits after a retention period expires,
using UUID-based entanglement tracking.

Similar to [`CutoffProt`](@ref), but designed to work with the UUID-based protocols.
When a qubit is deleted, an `EntanglementDeleteUUID` message is sent to the remote node.

$TYPEDFIELDS
"""
@kwdef struct CutoffProtUUID <: AbstractProtocol
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
end

function CutoffProtUUID(sim::Simulation, net::RegisterNet, node::Int; kwargs...)
    return CutoffProtUUID(; sim, net, node, kwargs...)
end

CutoffProtUUID(net::RegisterNet, node::Int; kwargs...) =
    CutoffProtUUID(get_time_tracker(net), net, node; kwargs...)

@resumable function (prot::CutoffProtUUID)()
    reg = prot.net[prot.node]
    while true
        for slot in reg
            islocked(slot) && continue
            @yield lock(slot)
            info = query(slot, EntanglementUUID, ❓, ❓, ❓)
            if isnothing(info)
                unlock(slot)
                continue
            end
            uuid, remote_node, remote_slot = info.tag[2], info.tag[3], info.tag[4]
            if now(prot.sim) - reg.tag_info[info.id][3] > prot.retention_time
                untag!(slot, info.id)
                traceout!(slot)
                if prot.announce
                    msg = Tag(EntanglementDeleteUUID, uuid, prot.node, slot.idx)
                    put!(
                        channel(prot.net, prot.node=>remote_node; permit_forward = true),
                        msg,
                    )
                    @debug "CutoffProtUUID @$(prot.node): Send delete message to $(remote_node) | message=`$msg` | time=$(now(prot.sim))"
                end
            end

            unlock(slot)
        end
        if isnothing(prot.period)
            @yield onchange(reg, Tag)
        else
            @yield timeout(prot.sim, prot.period::Float64)
        end
    end
end

"""
$TYPEDEF

A protocol running between two nodes that checks periodically for any entangled pairs
between the two nodes and consumes/empties the qubit slots, using UUID-based tracking.

This is the UUID-based variant of [`EntanglementConsumer`](@ref).

This protocol permits virtual edges, meaning it can operate between any two nodes
in the network regardless of whether they are physically connected by an edge.

$TYPEDFIELDS
"""
@kwdef struct EntanglementConsumerUUID <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex index of node A"""
    nodeA::Int
    """the vertex index of node B"""
    nodeB::Int
    """time period between successive queries on the nodes (`nothing` for queuing up and waiting for available pairs)"""
    period::Union{Float64,Nothing} = 0.1
    """stores the time and resulting observable from querying nodeA and nodeB for entanglement"""
    _log::Vector{@NamedTuple{t::Float64,obs1::Float64,obs2::Float64}} =
        @NamedTuple{t::Float64, obs1::Float64, obs2::Float64}[]
end

function EntanglementConsumerUUID(
    sim::Simulation,
    net::RegisterNet,
    nodeA::Int,
    nodeB::Int;
    kwargs...,
)
    return EntanglementConsumerUUID(; sim, net, nodeA, nodeB, kwargs...)
end

EntanglementConsumerUUID(net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...) =
    EntanglementConsumerUUID(get_time_tracker(net), net, nodeA, nodeB; kwargs...)

permits_virtual_edge(::EntanglementConsumerUUID) = true

@resumable function (prot::EntanglementConsumerUUID)()
    regA = prot.net[prot.nodeA]
    regB = prot.net[prot.nodeB]
    while true
        # Query for any pair with matching UUID between the two nodes
        queryresults_A = queryall(
            regA,
            EntanglementUUID,
            ❓,
            prot.nodeB,
            ❓;
            assigned = true,
            locked = false,
        )
        queryresults_B = queryall(
            regB,
            EntanglementUUID,
            ❓,
            prot.nodeA,
            ❓;
            assigned = true,
            locked = false,
        )

        if !isempty(queryresults_A) && !isempty(queryresults_B)
            # Find matching pairs
            query1 = queryresults_A[1]
            query2 = queryresults_B[1]

            q1 = query1.slot
            q2 = query2.slot

            @yield lock(q1) & lock(q2)

            if isassigned(q1) && isassigned(q2)
                @debug "$(timestr(prot.sim)) EntanglementConsumerUUID($(compactstr(regA)), $(compactstr(regB))): queries successful, consuming entanglement between .$(q1.idx) and .$(q2.idx)"
                untag!(q1, query1.id)
                untag!(q2, query2.id)
                ob1 = real(observable((q1, q2), Z ⊗ Z))
                ob2 = real(observable((q1, q2), X ⊗ X))

                traceout!(regA[q1.idx], regB[q2.idx])
                push!(prot._log, (now(prot.sim), ob1, ob2))
            end
            unlock(q1)
            unlock(q2)
        end

        if !isnothing(prot.period)
            @yield timeout(prot.sim, prot.period)
        else
            @yield onchange(regA, Tag) | onchange(regB, Tag)
        end
    end
end
