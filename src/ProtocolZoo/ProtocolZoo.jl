module ProtocolZoo

using QuantumSavory
import QuantumSavory: get_time_tracker, Tag, isolderthan, onchange, QueryOnRegResult
using QuantumSavory: Wildcard, alwaystrue
using QuantumSavory: timestr, compactstr
using QuantumSavory.CircuitZoo: EntanglementSwap, LocalEntanglementSwap

using DocStringExtensions

using Distributions: Geometric
using ConcurrentSim: Simulation, @yield, timeout, @process, now
import ConcurrentSim: Process
import ResumableFunctions
using ResumableFunctions: @resumable
import SumTypes
using PrettyTables: PrettyTables, pretty_table

export
    # protocols
    EntanglerProt, SwapperProt, EntanglementTracker, EntanglementConsumer, CutoffProt,
    # tags
    EntanglementCounterpart, EntanglementHistory, EntanglementUpdateX, EntanglementUpdateZ,
    EntanglementID, NO_ENTANGLEMENT_ID, fresh_entanglement_id, combine_entanglement_ids,
    # from Switches
    SimpleSwitchDiscreteProt, SwitchRequest,
    # from QTCP
    QDatagram, Flow, LinkLevelRequest,
    QTCPPairBegin, QTCPPairEnd,
    LinkLevelReply, LinkLevelReplyAtHop, LinkLevelReplyAtSource,
    NetworkNodeController, EndNodeController, LinkController
abstract type AbstractProtocol end

"""
Check whether a protocol permits virtual edges between nodes.

Virtual edges refer to protocol connections between two nodes that do not correspond
to actual network edges/links. Some protocols like [`EntanglementConsumer`](@ref) can operate
between any two nodes in the network regardless of physical connectivity.
"""
permits_virtual_edge(::AbstractProtocol) = false

get_time_tracker(prot::AbstractProtocol) = prot.sim::Simulation

Process(prot::AbstractProtocol, args...; kwargs...) = Process((e,a...;k...)->prot(a...;k...), get_time_tracker(prot), args...; kwargs...)

"""Display all available background types in QuantumSavory along with their documentation.

The `InteractiveUtils` package must be installed and imported."""
function available_protocol_types end

const QueryArgs = Union{Int,Function,Wildcard}

include("entanglement_ids.jl")


"""
$TYPEDEF

Indicates the current entanglement status with a remote node's slot. Added when a new entanglement is generated through [`EntanglerProt`](@ref) or when a swap happens and
 the [`EntanglementTracker`](@ref) receives an [`EntanglementUpdate`] message.

$TYPEDFIELDS
"""
@kwdef struct EntanglementCounterpart
    "the id of the remote node to which we are entangled"
    remote_node::Int
    "the slot in the remote node containing the qubit we are entangled to"
    remote_slot::Int
    "the identifier of the entangled pair"
    pair_id::EntanglementID
end
EntanglementCounterpart(remote_node::Int, remote_slot::Int) = EntanglementCounterpart(remote_node, remote_slot, NO_ENTANGLEMENT_ID)
Base.show(io::IO, tag::EntanglementCounterpart) = print(io, "Entangled to $(tag.remote_node).$(tag.remote_slot) with id $(tag.pair_id)")
Tag(tag::EntanglementCounterpart) = Tag(EntanglementCounterpart, tag.remote_node, tag.remote_slot, tag.pair_id)

function _tag_entanglement_counterpart!(slot, remote_node, remote_slot, pair_id, protocol)
    existing = query(slot, EntanglementCounterpart, ❓, ❓, ❓)
    if !isnothing(existing)
        new_tag = Tag(EntanglementCounterpart, remote_node, remote_slot, pair_id)
        @error "$(protocol): adding `$new_tag` to a slot that already has an " *
               "`EntanglementCounterpart` tag" slot existing
    end
    tag!(slot, EntanglementCounterpart, remote_node, remote_slot, pair_id)
end

"""
$TYPEDEF

This tag is used to store the outdated entanglement information after a
swap. It helps to direct incoming entanglement update messages to the right node after a swap.
It helps in situations when locally we have performed a swap, but we are now receiving a message
from a distant node that does not know yet that the swap has occurred (thus the distant node might
have outdated information about who is entangled to whom and we need to update that information).

$TYPEDFIELDS
"""
@kwdef struct EntanglementHistory
    "the id of the remote node we used to be entangled to"
    remote_node::Int
    "the slot of the remote node we used to be entangled to"
    remote_slot::Int
    "the id of remote node to which we are entangled after the swap"
    swap_remote_node::Int
    "the slot of the remote node to which we are entangled after the swap"
    swap_remote_slot::Int
    "the slot in this register with whom we performed a swap"
    swapped_local::Int
    "the pair-id chunk corresponding to `remote_node.remote_slot`"
    local_chunk_id::EntanglementID
    "the pair-id chunk corresponding to `swap_remote_node.swap_remote_slot`"
    swapped_chunk_id::EntanglementID
end
EntanglementHistory(remote_node::Int, remote_slot::Int, swap_remote_node::Int, swap_remote_slot::Int, swapped_local::Int) = EntanglementHistory(remote_node, remote_slot, swap_remote_node, swap_remote_slot, swapped_local, NO_ENTANGLEMENT_ID, NO_ENTANGLEMENT_ID)
Base.show(io::IO, tag::EntanglementHistory) = print(io, "Was entangled to $(tag.remote_node).$(tag.remote_slot) with chunk id $(tag.local_chunk_id), but swapped with .$(tag.swapped_local) which was entangled to $(tag.swap_remote_node).$(tag.swap_remote_slot) with chunk id $(tag.swapped_chunk_id)")
Tag(tag::EntanglementHistory) = Tag(EntanglementHistory, tag.remote_node, tag.remote_slot, tag.swap_remote_node, tag.swap_remote_slot, tag.swapped_local, tag.local_chunk_id, tag.swapped_chunk_id)

"""
$TYPEDEF

This tag arrives as a message from a remote node to which the current node was entangled to update the
entanglement information and apply an `X` correction after the remote node performs an entanglement swap.

$TYPEDFIELDS
"""
@kwdef struct EntanglementUpdateX
    "the pair id currently known by the receiver for the target slot"
    target_pair_id::EntanglementID
    "the pair-id chunk to combine into the target pair"
    other_pair_id::EntanglementID
    "the id of the node to which you were entangled before the swap"
    past_local_node::Int
    "the slot of the node to which you were entangled before the swap"
    past_local_slot::Int
    "the slot of your node that we were entangled to"
    past_remote_slot::Int
    "the id of the node to which you are now entangled after the swap"
    new_remote_node::Int
    "the slot of the node to which you are now entangled after the swap"
    new_remote_slot::Int
    "what Pauli correction you need to perform"
    correction::Int
end
EntanglementUpdateX(past_local_node::Int, past_local_slot::Int, past_remote_slot::Int, new_remote_node::Int, new_remote_slot::Int, correction::Int) = EntanglementUpdateX(NO_ENTANGLEMENT_ID, NO_ENTANGLEMENT_ID, past_local_node, past_local_slot, past_remote_slot, new_remote_node, new_remote_slot, correction)
Base.show(io::IO, tag::EntanglementUpdateX) = print(io, "Update pair $(tag.target_pair_id) at slot .$(tag.past_remote_slot) which used to be entangled to $(tag.past_local_node).$(tag.past_local_slot) to be entangled to $(tag.new_remote_node).$(tag.new_remote_slot), combine with $(tag.other_pair_id), and apply correction Z$(tag.correction)")
Tag(tag::EntanglementUpdateX) = Tag(EntanglementUpdateX, tag.target_pair_id, tag.other_pair_id, tag.past_local_node, tag.past_local_slot, tag.past_remote_slot, tag.new_remote_node, tag.new_remote_slot, tag.correction)

"""
$TYPEDEF

This tag arrives as a message from a remote node to which the current node was entangled to update the
entanglement information and apply a `Z` correction after the remote node performs an entanglement swap.

$TYPEDFIELDS
"""
@kwdef struct EntanglementUpdateZ
    "the pair id currently known by the receiver for the target slot"
    target_pair_id::EntanglementID
    "the pair-id chunk to combine into the target pair"
    other_pair_id::EntanglementID
    "the id of the node to which you were entangled before the swap"
    past_local_node::Int
    "the slot of the node to which you were entangled before the swap"
    past_local_slot::Int
    "the slot of your node that we were entangled to"
    past_remote_slot::Int
    "the id of the node to which you are now entangled after the swap"
    new_remote_node::Int
    "the slot of the node to which you are now entangled after the swap"
    new_remote_slot::Int
    "what Pauli correction you need to perform"
    correction::Int
end
EntanglementUpdateZ(past_local_node::Int, past_local_slot::Int, past_remote_slot::Int, new_remote_node::Int, new_remote_slot::Int, correction::Int) = EntanglementUpdateZ(NO_ENTANGLEMENT_ID, NO_ENTANGLEMENT_ID, past_local_node, past_local_slot, past_remote_slot, new_remote_node, new_remote_slot, correction)
Base.show(io::IO, tag::EntanglementUpdateZ) = print(io, "Update pair $(tag.target_pair_id) at slot .$(tag.past_remote_slot) which used to be entangled to $(tag.past_local_node).$(tag.past_local_slot) to be entangled to $(tag.new_remote_node).$(tag.new_remote_slot), combine with $(tag.other_pair_id), and apply correction X$(tag.correction)")
Tag(tag::EntanglementUpdateZ) = Tag(EntanglementUpdateZ, tag.target_pair_id, tag.other_pair_id, tag.past_local_node, tag.past_local_slot, tag.past_remote_slot, tag.new_remote_node, tag.new_remote_slot, tag.correction)

"""
$TYPEDEF

This tag arrives as a message from a remote node's Cutoff Protocol to which the current node was entangled,
to update the classical metadata of the entangled slot and empty it.
It is also stored at a node to handle incoming `EntanglementUpdate` and `EntanglementDelete` messages.

$TYPEDFIELDS

See also: [`CutoffProt`](@ref)
"""
@kwdef struct EntanglementDelete
    "the pair id targeted by this deletion"
    target_pair_id::EntanglementID
    "the node that sent the deletion announcement message after they delete their local qubit"
    send_node::Int
    "the sender's slot containing the decohered qubit"
    send_slot::Int
    "the node receiving the message for qubit deletion"
    rec_node::Int
    "the slot containing decohered qubit"
    rec_slot::Int
end
EntanglementDelete(send_node::Int, send_slot::Int, rec_node::Int, rec_slot::Int) = EntanglementDelete(NO_ENTANGLEMENT_ID, send_node, send_slot, rec_node, rec_slot)
Base.show(io::IO, tag::EntanglementDelete) = print(io, "Deleted pair $(tag.target_pair_id) at $(tag.send_node).$(tag.send_slot) which was entangled to $(tag.rec_node).$(tag.rec_slot)")
Tag(tag::EntanglementDelete) = Tag(EntanglementDelete, tag.target_pair_id, tag.send_node, tag.send_slot, tag.rec_node, tag.rec_slot)

"""
$TYPEDEF

A protocol that generates entanglement between two nodes.
Whenever a pair of empty slots is available, the protocol locks them
and starts probabilistic attempts to establish entanglement.

$TYPEDFIELDS
"""
@kwdef struct EntanglerProt <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation # TODO check that
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
    """Tag to be added to the entangled qubits or nothing to not add any tag. `EntanglementCounterpart` tags include a pair ID; custom tags keep the legacy `tag(remote_node, remote_slot)` shape."""
    tag::Union{DataType,Nothing} = EntanglementCounterpart
end

"""Convenience constructor for specifying `rate` of generation instead of success probability and time"""
function EntanglerProt(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int; rate::Union{Nothing,Float64}=nothing, kwargs...)
    if isnothing(rate)
        return EntanglerProt(;sim, net, nodeA, nodeB, kwargs...)
    else
        return EntanglerProt(;sim, net, nodeA, nodeB, kwargs..., success_prob=0.001, attempt_time=0.001/rate)
    end
end

EntanglerProt(net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...) = EntanglerProt(get_time_tracker(net), net, nodeA, nodeB; kwargs...)

#TODO """Convenience constructor for specifying `fidelity` of generation instead of success probability and time"""

@resumable function (prot::EntanglerProt)()
    rounds = prot.rounds
    round = 1
    last_a, last_b = nothing, nothing
    regA = prot.net[prot.nodeA]
    regB = prot.net[prot.nodeB]
    while rounds != 0
        tagtype = prot.tag
        isentangled = !isnothing(tagtype) && (
            tagtype === EntanglementCounterpart ?
            !isnothing(query(regA, tagtype::DataType, prot.nodeB, ❓, ❓; assigned=true)) :
            !isnothing(query(regA, tagtype::DataType, prot.nodeB, ❓; assigned=true))
        )
        margin = isentangled ? prot.margin : prot.hardmargin
        (; chooseslotA, chooseslotB, randomize, uselock) = prot
        a_ = findfreeslot(regA; chooseslot=chooseslotA, randomize=randomize, locked=!uselock, margin=margin)
        b_ = findfreeslot(regB; chooseslot=chooseslotB, randomize=randomize, locked=!uselock, margin=margin)

        if isnothing(a_) || isnothing(b_)
            if isnothing(prot.retry_lock_time)
                @debug "$(timestr(prot.sim)) EntanglerProt($(compactstr(regA)), $(compactstr(regB))), round $(round): Failed to find free slots, waiting for changes to tags..."
                @yield onchange(regA, Tag) | onchange(regB, Tag)
            else
                @debug "$(timestr(prot.sim)) EntanglerProt($(compactstr(regA)), $(compactstr(regB))), round $(round): Failed to find free slots, waiting a fixed amount of time..."
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
            initialize!((a,b), prot.pairstate; time=now(prot.sim))
            @yield timeout(prot.sim, prot.local_busy_time_post)

            # generate a random identifier for the new pair
            pair_id = fresh_entanglement_id()
            # tag local node a with EntanglementCounterpart remote_node_idx_b remote_slot_idx_b pair_id
            if tagtype === EntanglementCounterpart
                _tag_entanglement_counterpart!(a, prot.nodeB, b.idx, pair_id, "EntanglerProt")
            elseif !isnothing(tagtype)
                tag!(a, tagtype::DataType, prot.nodeB, b.idx)
            end
            last_a = a.idx
            # tag local node b with EntanglementCounterpart remote_node_idx_a remote_slot_idx_a pair_id
            if tagtype === EntanglementCounterpart
                _tag_entanglement_counterpart!(b, prot.nodeA, a.idx, pair_id, "EntanglerProt")
            elseif !isnothing(tagtype)
                tag!(b, tagtype::DataType, prot.nodeA, a.idx)
            end
            last_b = b.idx

            @debug "$(timestr(prot.sim)) EntanglerProt($(compactstr(regA)), $(compactstr(regB))), round $(round): Entangled .$(a.idx) and .$(b.idx)"
        else
            @yield timeout(prot.sim, prot.attempts * prot.attempt_time)
            @debug "$(timestr(prot.sim)) EntanglerProt($(compactstr(regA)), $(compactstr(regB))), round $(round): Performed the maximum number of attempts and gave up"
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

A protocol, running at a given node, listening for messages that indicate something has happened to a remote qubit entangled with one of the local qubits.

$TYPEDFIELDS
"""
@kwdef struct EntanglementTracker <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex of the node where the tracker is working"""
    node::Int
end

EntanglementTracker(net::RegisterNet, node::Int) = EntanglementTracker(get_time_tracker(net), net, node)

@resumable function (prot::EntanglementTracker)()
    nodereg = prot.net[prot.node]
    mb = messagebuffer(prot.net, prot.node)
    while true
        workwasdone = true # waiting is not enough because we might have multiple rounds of work to do
        while workwasdone
            workwasdone = false
            for (updatetagsymbol, updategate) in ((EntanglementUpdateX, Z), (EntanglementUpdateZ, X), (EntanglementDelete, nothing)) # TODO this is getting ugly. Refactor EntanglementUpdateX and EntanglementUpdateZ to be the same parameterized tag
                # look for EntanglementUpdate? or EntanglementDelete message sent to us
                if !isnothing(updategate) # EntanglementUpdate
                    msg = querydelete!(mb, updatetagsymbol, ❓, ❓, ❓, ❓, ❓, ❓, ❓, ❓)
                    isnothing(msg) && continue
                    (src, (_, target_pair_id, other_pair_id, pastremotenode, pastremoteslotid, localslotid, newremotenode, newremoteslotid, correction)) = msg
                    target_pair_id = target_pair_id::EntanglementID
                    other_pair_id = other_pair_id::EntanglementID
                else # EntanglementDelete
                    msg = querydelete!(mb, updatetagsymbol, ❓, ❓, ❓, ❓, ❓)
                    isnothing(msg) && continue
                    (src, (_, target_pair_id, pastremotenode, pastremoteslotid, _, localslotid)) = msg
                    target_pair_id = target_pair_id::EntanglementID
                    other_pair_id = NO_ENTANGLEMENT_ID
                    newremotenode = -1
                    newremoteslotid = -1
                    correction = 0
                end

                @debug "EntanglementTracker @$(prot.node): Received from $(msg.src).$(pastremoteslotid) | message=`$(msg.tag)` | time=$(now(prot.sim))"
                workwasdone = true
                localslot = nodereg[localslotid]

                new_pair_id = isnothing(updategate) ? target_pair_id : combine_entanglement_ids(target_pair_id::EntanglementID, other_pair_id::EntanglementID)

                # Check if the local slot is still present and believed to be entangled.
                # The physical slot lock is only needed when we may mutate the live qubit.
                # If no matching counterpart tag is present, fall through to the history
                # metadata path without waiting behind unrelated reuse of an empty slot.
                counterpart = query(localslot, EntanglementCounterpart, pastremotenode, pastremoteslotid, target_pair_id)
                if !isnothing(counterpart)
                    @debug "EntanglementTracker @$(prot.node): EntanglementCounterpart requesting lock at $(now(prot.sim))"
                    @yield lock(localslot)
                    @debug "EntanglementTracker @$(prot.node): EntanglementCounterpart getting lock at $(now(prot.sim))"
                    counterpart = querydelete!(localslot, EntanglementCounterpart, pastremotenode, pastremoteslotid, target_pair_id)
                    if !isnothing(counterpart)
                        if !isassigned(localslot)
                            unlock(localslot)
                            error("There was an error in the entanglement tracking protocol `EntanglementTracker`. We were attempting to forward a classical message from a node that performed a swap to the remote entangled node. However, on reception of that message it was found that the remote node has lost track of its part of the entangled state although it still keeps a `Tag` as a record of it being present.") # TODO make it configurable whether an error is thrown and plug it into the logging module
                        end
                        if !isnothing(updategate) # EntanglementUpdate
                            # Pauli frame correction gate
                            if correction==2
                                apply!(localslot, updategate)
                            end
                            if newremotenode != -1 #TODO: this is a bit hacky
                                # tag local with updated EntanglementCounterpart new_remote_node new_remote_slot_idx
                                _tag_entanglement_counterpart!(
                                    localslot, newremotenode, newremoteslotid,
                                    new_pair_id, "EntanglementTracker"
                                )
                            else
                                _tag_entanglement_counterpart!(
                                    localslot, pastremotenode, pastremoteslotid,
                                    target_pair_id, "EntanglementTracker"
                                )
                            end
                        else # EntanglementDelete
                            traceout!(localslot)
                        end
                        unlock(localslot)
                        continue
                    end
                    unlock(localslot)
                end

                # If there is nothing still stored locally, check if we have a record of the entanglement being swapped to a different remote node,
                # and forward the message to that node.
                history = querydelete!(localslot, EntanglementHistory,
                                    pastremotenode, pastremoteslotid, # who we were entangled to (node, slot)
                                    ❓, ❓,                             # who we swapped with (node, slot)
                                    ❓,                                 # which local slot used to be entangled with whom we swapped with
                                    target_pair_id, ❓)                # pair-id chunks for this side and the swapped side
                if !isnothing(history)
                    _, _, _, whoweswappedwith_node, whoweswappedwith_slotidx, swappedlocal_slotidx, local_chunk_id, swapped_chunk_id = history.tag
                    local_chunk_id = local_chunk_id::EntanglementID
                    swapped_chunk_id = swapped_chunk_id::EntanglementID
                    forwarded_target_pair_id = combine_entanglement_ids(local_chunk_id::EntanglementID, swapped_chunk_id::EntanglementID)
                    if !isnothing(updategate) # EntanglementUpdate
                        # A history tag stores the two chunks joined by the
                        # local swap. An update from this side advances only
                        # this side's chunk; the end-to-end ID is recomputed
                        # when notifying the opposite side.
                        updated_local_chunk_id = combine_entanglement_ids(local_chunk_id::EntanglementID, other_pair_id::EntanglementID)
                        tag!(localslot, EntanglementHistory, newremotenode, newremoteslotid, whoweswappedwith_node, whoweswappedwith_slotidx, swappedlocal_slotidx, updated_local_chunk_id, swapped_chunk_id)
                        @debug "EntanglementTracker @$(prot.node): history=`$(history)` | message=`$msg` | Sending to $(whoweswappedwith_node).$(whoweswappedwith_slotidx)"
                        msghist = Tag(updatetagsymbol, forwarded_target_pair_id, other_pair_id, pastremotenode, pastremoteslotid, whoweswappedwith_slotidx, newremotenode, newremoteslotid, correction)
                        put!(channel(prot.net, prot.node=>whoweswappedwith_node; permit_forward=true), msghist)
                    else # EntanglementDelete
                        # We have a delete message but the qubit was swapped so add a tag and forward to swapped node
                        @debug "EntanglementTracker @$(prot.node): history=`$(history)` | message=`$msg` | Sending to $(whoweswappedwith_node).$(whoweswappedwith_slotidx)"
                        msghist = Tag(updatetagsymbol, forwarded_target_pair_id, pastremotenode, pastremoteslotid, whoweswappedwith_node, whoweswappedwith_slotidx)
                        tag!(localslot, updatetagsymbol, target_pair_id, prot.node, localslot.idx, pastremotenode, pastremoteslotid)
                        put!(channel(prot.net, prot.node=>whoweswappedwith_node; permit_forward=true), msghist)
                    end
                    continue
                end

                # Finally, if there the history of a swap is not present in the log anymore,
                # it must be because a delete message was received, and forwarded,
                # and the entanglement history was deleted, and replaced with an entanglement delete tag.
                if !isnothing(querydelete!(localslot, EntanglementDelete, target_pair_id, prot.node, localslot.idx, pastremotenode, pastremoteslotid)) #deletion from both sides of the swap, deletion msg when both qubits of a pair are deleted, or when EU arrives after ED at swap node with two simultaneous swaps and deletion on one side
                    if !(isnothing(updategate)) # EntanglementUpdate
                        # to handle a possible delete-swap-swap case, we need to update the EntanglementDelete tag
                        tag!(localslot, EntanglementDelete, combine_entanglement_ids(target_pair_id::EntanglementID, other_pair_id::EntanglementID), prot.node, localslot.idx, newremotenode, newremoteslotid)
                        @debug "EntanglementTracker @$(prot.node): message=`$msg` for deleted qubit handled and EntanglementDelete tag updated"
                    else # EntanglementDelete
                        # when the message is EntanglementDelete and the slot history also has an EntanglementDelete tag (both qubits were deleted), do nothing
                        @debug "EntanglementTracker @$(prot.node): message=`$msg` is for a deleted qubit and is thus dropped"
                    end
                    continue
                end

                # With pair IDs, unmatched updates/deletes should be rare: a live
                # counterpart, a history entry, or a delete marker should normally
                # carry the target ID until the message is handled. The expected
                # benign cause is a bounded history log that discarded the needed
                # entry before a delayed message arrived.
                stale_kind = isnothing(updategate) ? "delete" : "update"
                @warn "EntanglementTracker @$(prot.node): stale $(stale_kind) message=`$msg` is dropped. This is likely because SwapperProt.max_history_per_slot is too small and history garbage collection removed a still-needed entry; consider increasing max_history_per_slot on the swapper. If the history cap is not the cause, this is a tracker bug."
                continue
            end
        end
        @debug "EntanglementTracker @$(prot.node): Starting message wait at $(now(prot.sim)) with MessageBuffer containing: $(mb.buffer)"
        @yield onchange(mb)
        @debug "EntanglementTracker @$(prot.node): Message wait ends at $(now(prot.sim))"
    end
end

include("consumer.jl")
include("cutoff.jl")
include("swapping.jl")
include("switches.jl")
using .Switches
include("qtcp.jl")
using .QTCP
include("mbqc.jl")
using .MBQCEntanglementDistillation

include("show.jl")

end # module
