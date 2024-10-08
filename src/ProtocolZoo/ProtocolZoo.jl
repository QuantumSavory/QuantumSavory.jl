module ProtocolZoo

using QuantumSavory
import QuantumSavory: get_time_tracker, Tag, isolderthan
using QuantumSavory: Wildcard
using QuantumSavory.CircuitZoo: EntanglementSwap, LocalEntanglementSwap, EntanglementFusion

using DocStringExtensions

using Distributions: Geometric
using ConcurrentSim: Simulation, @yield, timeout, @process, now, Event, succeed, state, idle, StopSimulation
import ConcurrentSim: Process
import ResumableFunctions
using ResumableFunctions: @resumable
import SumTypes

export
    # protocols
    EntanglerProt, SelectedEntanglerProt, SwapperProt, FusionProt, EntanglementTracker, EntanglementConsumer, GHZConsumer, CutoffProt,
    # tags
    EntanglementCounterpart, FusionCounterpart, EntanglementHistory, EntanglementUpdateX, EntanglementUpdateZ, Piecemaker,
    # from Switches
    SimpleSwitchDiscreteProt, FusionSwitchDiscreteProt, SwitchRequest

abstract type AbstractProtocol end

get_time_tracker(prot::AbstractProtocol) = prot.sim::Simulation

Process(prot::AbstractProtocol, args...; kwargs...) = Process((e,a...;k...)->prot(a...;k...), get_time_tracker(prot), args...; kwargs...)

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
end
Base.show(io::IO, tag::EntanglementCounterpart) = print(io, "Entangled to $(tag.remote_node).$(tag.remote_slot)")
Tag(tag::EntanglementCounterpart) = Tag(EntanglementCounterpart, tag.remote_node, tag.remote_slot)


"""
$TYPEDEF

Indicates the current entanglement status with a remote node's slot. Added when a new qubit is fused into the GHZ state through [`FusionProt`](@ref).

$TYPEDFIELDS
"""
@kwdef struct FusionCounterpart
    "the id of the remote node to which we are entangled"
    remote_node::Int
    "the slot in the remote node containing the qubit we are entangled to"
    remote_slot::Int
end
Base.show(io::IO, tag::FusionCounterpart) = print(io, "GHZ state shared with $(tag.remote_node).$(tag.remote_slot)")
Tag(tag::FusionCounterpart) = Tag(FusionCounterpart, tag.remote_node, tag.remote_slot)

"""
$TYPEDEF

Indicates the piecemaker responsible for fusions of a remote node's slot. 

$TYPEDFIELDS
"""
@kwdef struct Piecemaker
    "the id of the switch node"
    node::Int
    "the slot in the switch node containing piecemaker qubit"
    slot::Int
end
Base.show(io::IO, tag::Piecemaker) = print(io, "Piecemaker slot at $(tag.node).$(tag.slot)")
Tag(tag::Piecemaker) = Tag(Piecemaker, tag.node, tag.slot)



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
end
Base.show(io::IO, tag::EntanglementHistory) = print(io, "Was entangled to $(tag.remote_node).$(tag.remote_slot), but swapped with .$(tag.swapped_local) which was entangled to $(tag.swap_remote_node).$(tag.swap_remote_slot)")
Tag(tag::EntanglementHistory) = Tag(EntanglementHistory, tag.remote_node, tag.remote_slot, tag.swap_remote_node, tag.swap_remote_slot, tag.swapped_local)

"""
$TYPEDEF

This tag arrives as a message from a remote node to which the current node was entangled to update the
entanglement information and apply an `X` correction after the remote node performs an entanglement swap.

$TYPEDFIELDS
"""
@kwdef struct EntanglementUpdateX
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
Base.show(io::IO, tag::EntanglementUpdateX) = print(io, "Update slot .$(tag.past_remote_slot) which used to be entangled to $(tag.past_local_node).$(tag.past_local_slot) to be entangled to $(tag.new_remote_node).$(tag.new_remote_slot) and apply correction Z$(tag.correction)")
Tag(tag::EntanglementUpdateX) = Tag(EntanglementUpdateX, tag.past_local_node, tag.past_local_slot, tag.past_remote_slot, tag.new_remote_node, tag.new_remote_slot, tag.correction)

"""
$TYPEDEF

This tag arrives as a message from a remote node to which the current node was entangled to update the
entanglement information and apply a `Z` correction after the remote node performs an entanglement swap.

$TYPEDFIELDS
"""
@kwdef struct EntanglementUpdateZ
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
Base.show(io::IO, tag::EntanglementUpdateZ) = print(io, "Update slot .$(tag.past_remote_slot) which used to be entangled to $(tag.past_local_node).$(tag.past_local_slot) to be entangled to $(tag.new_remote_node).$(tag.new_remote_slot) and apply correction X$(tag.correction)")
Tag(tag::EntanglementUpdateZ) = Tag(EntanglementUpdateZ, tag.past_local_node, tag.past_local_slot, tag.past_remote_slot, tag.new_remote_node, tag.new_remote_slot, tag.correction)

"""
$TYPEDEF

This tag arrives as a message from a remote node's Cutoff Protocol to which the current node was entangled,
to update the classical metadata of the entangled slot and empty it.
It is also stored at a node to handle incoming `EntanglementUpdate` and `EntanglementDelete` messages.

$TYPEDFIELDS

See also: [`CutoffProt`](@ref)
"""
@kwdef struct EntanglementDelete
    "the node that sent the deletion announcement message after they delete their local qubit"
    send_node::Int
    "the sender's slot containing the decohered qubit"
    send_slot::Int
    "the node receiving the message for qubit deletion"
    rec_node::Int
    "the slot containing decohered qubit"
    rec_slot::Int
end
Base.show(io::IO, tag::EntanglementDelete) = print(io, "Deleted $(tag.send_node).$(tag.send_slot) which was entangled to $(tag.rec_node).$(tag.rec_slot)")
Tag(tag::EntanglementDelete) = Tag(EntanglementDelete, tag.send_node, tag.send_slot, tag.rec_node, tag.rec_slot)

"""
$TYPEDEF

A protocol that generates entanglement between two nodes.
Whenever a pair of empty slots is available, the protocol locks them
and starts probabilistic attempts to establish entanglement.

$TYPEDFIELDS
"""
@kwdef struct EntanglerProt{LT} <: AbstractProtocol where {LT<:Union{Float64,Nothing}}
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation # TODO check that
    """a network graph of registers"""
    net::RegisterNet
    """the vertex index of node A"""
    nodeA::Int
    """the vertex index of node B"""
    nodeB::Int
    """the state being generated (supports symbolic, numeric, noisy, and pure)"""
    pairstate = StabilizerState("ZZ XX")
    """success probability of one attempt of entanglement generation"""
    success_prob::Float64 = 0.001
    """duration of single entanglement attempt"""
    attempt_time::Float64 = 0.001
    """fixed "busy time" duration immediately before starting entanglement generation attempts"""
    local_busy_time_pre::Float64 = 0.0
    """fixed "busy time" duration immediately after the a successful entanglement generation attempt"""
    local_busy_time_post::Float64 = 0.0
    """how long to wait before retrying to lock qubits if no qubits are available (`nothing` for queuing up)"""
    retry_lock_time::LT = 0.1
    """how many rounds of this protocol to run (`-1` for infinite)"""
    rounds::Int = -1
    """maximum number of attempts to make per round (`-1` for infinite)"""
    attempts::Int = -1
    """whether the protocol should find the first available free slots in the nodes to be entangled or check for free slots randomly from the available slots"""
    randomize::Bool = false
    """Repeated rounds of this protocol may lead to monopolizing all slots of a pair of registers, starving or deadlocking other protocols. This field can be used to always leave a minimum number of slots free if there already exists entanglement between the current pair of nodes."""
    margin::Int = 0
    """Like `margin`, but it is enforced even when no entanglement has been established yet. Usually smaller than `margin`."""
    hardmargin::Int = 0
end

"""Convenience constructor for specifying `rate` of generation instead of success probability and time"""
function EntanglerProt(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int; rate::Union{Nothing,Float64}=nothing, kwargs...)
    if isnothing(rate)
        return EntanglerProt(;sim, net, nodeA, nodeB, kwargs...)
    else
        return EntanglerProt(;sim, net, nodeA, nodeB, kwargs..., success_prob=0.001, attempt_time=0.001/rate)
    end
end

#TODO """Convenience constructor for specifying `fidelity` of generation instead of success probability and time"""

@resumable function (prot::EntanglerProt)()
    rounds = prot.rounds
    round = 1
    while rounds != 0
        isentangled = !isnothing(query(prot.net[prot.nodeA], EntanglementCounterpart, prot.nodeB, ❓; assigned=true))
        margin = isentangled ? prot.margin : prot.hardmargin
        a_ = findfreeslot(prot.net[prot.nodeA]; randomize=prot.randomize, margin=margin)
        b_ = findfreeslot(prot.net[prot.nodeB]; randomize=prot.randomize, margin=margin)

        if isnothing(a_) || isnothing(b_)
            isnothing(prot.retry_lock_time) && error("We do not yet support waiting on register to make qubits available") # TODO
            @debug "EntanglerProt between $(prot.nodeA) and $(prot.nodeB)|round $(round): Failed to find free slots. \nGot:\n1. \t $a_ \n2.\t $b_ \n retrying..."
            @yield timeout(prot.sim, prot.retry_lock_time)
            continue
        end
        # we are now certain that a_ and b_ are not nothing. The compiler is not smart enough to figure this out
        # on its own, so we need to tell it explicitly. A new variable name is needed due to @resumable.
        a = a_::RegRef
        b = b_::RegRef

        @yield lock(a) & lock(b) # this yield is expected to return immediately

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

            # tag local node a with EntanglementCounterpart remote_node_idx_b remote_slot_idx_b
            tag!(a, EntanglementCounterpart, prot.nodeB, b.idx)
            # tag local node b with EntanglementCounterpart remote_node_idx_a remote_slot_idx_a
            tag!(b, EntanglementCounterpart, prot.nodeA, a.idx)

            @debug "EntanglerProt between $(prot.nodeA) and $(prot.nodeB)|round $(round): Entangled .$(a.idx) and .$(b.idx)"
        else
            @yield timeout(prot.sim, prot.attempts * prot.attempt_time)
            @debug "EntanglerProt between $(prot.nodeA) and $(prot.nodeB)|round $(round): Performed the maximum number of attempts and gave up"
        end
        unlock(a)
        unlock(b)
        rounds==-1 || (rounds -= 1)
        round += 1
    end
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
                    msg = querydelete!(mb, updatetagsymbol, ❓, ❓, ❓, ❓, ❓, ❓)
                    isnothing(msg) && continue
                    (src, (_, pastremotenode, pastremoteslotid, localslotid, newremotenode, newremoteslotid, correction)) = msg
                else # EntanglementDelete
                    msg = querydelete!(mb, updatetagsymbol, ❓, ❓, ❓, ❓)
                    isnothing(msg) && continue
                    (src, (_, pastremotenode, pastremoteslotid, _, localslotid)) = msg
                end

                @debug "EntanglementTracker @$(prot.node): Received from $(msg.src).$(msg.tag[3]) | message=`$(msg.tag)` | time=$(now(prot.sim))"
                workwasdone = true
                localslot = nodereg[localslotid]

                # Check if the local slot is still present and believed to be entangled.
                # We will need to perform a correction operation due to the swap or a deletion due to the qubit being thrown out,
                # but there will be no message forwarding necessary.
                @debug "EntanglementTracker @$(prot.node): EntanglementCounterpart requesting lock at $(now(prot.sim))"
                @yield lock(localslot)
                @debug "EntanglementTracker @$(prot.node): EntanglementCounterpart getting lock at $(now(prot.sim))"
                counterpart = querydelete!(localslot, EntanglementCounterpart, pastremotenode, pastremoteslotid)
                unlock(localslot)
                if !isnothing(counterpart)
                    # time_before_lock = now(prot.sim)
                    @yield lock(localslot)
                    # time_after_lock = now(prot.sim)
                    # time_before_lock != time_after_lock && @debug "EntanglementTracker @$(prot.node): Needed Δt=$(time_after_lock-time_before_lock) to get a lock"
                    if !isassigned(localslot)
                        unlock(localslot)
                        error("There was an error in the entanglement tracking protocol `EntanglementTracker`. We were attempting to forward a classical message from a node that performed a swap to the remote entangled node. However, on reception of that message it was found that the remote node has lost track of its part of the entangled state although it still keeps a `Tag` as a record of it being present.") # TODO make it configurable whether an error is thrown and plug it into the logging module
                    end
                    if !isnothing(updategate) # EntanglementUpdate
                        # Pauli frame correction gate
                        if correction==2
                            apply!(localslot, updategate)
                        end
                        # tag local with updated EntanglementCounterpart new_remote_node new_remote_slot_idx
                        tag!(localslot, EntanglementCounterpart, newremotenode, newremoteslotid)
                    else # EntanglementDelete
                        traceout!(localslot)
                    end
                    unlock(localslot)
                    continue
                end

                # If there is nothing still stored locally, check if we have a record of the entanglement being swapped to a different remote node,
                # and forward the message to that node.
                history = querydelete!(localslot, EntanglementHistory,
                                    pastremotenode, pastremoteslotid, # who we were entangled to (node, slot)
                                    ❓, ❓,                             # who we swapped with (node, slot)
                                    ❓)                                # which local slot used to be entangled with whom we swapped with
                if !isnothing(history)
                    _, _, _, whoweswappedwith_node, whoweswappedwith_slotidx, swappedlocal_slotidx = history.tag
                    if !isnothing(updategate) # EntanglementUpdate
                        # Forward the update tag to the swapped node and store a new history tag so that we can forward the next update tag to the new node
                        tag!(localslot, EntanglementHistory, newremotenode, newremoteslotid, whoweswappedwith_node, whoweswappedwith_slotidx, swappedlocal_slotidx)
                        @debug "EntanglementTracker @$(prot.node): history=`$(history)` | message=`$msg` | Sending to $(whoweswappedwith_node).$(whoweswappedwith_slotidx)"
                        msghist = Tag(updatetagsymbol, pastremotenode, pastremoteslotid, whoweswappedwith_slotidx, newremotenode, newremoteslotid, correction)
                        put!(channel(prot.net, prot.node=>whoweswappedwith_node; permit_forward=true), msghist)
                    else # EntanglementDelete
                        # We have a delete message but the qubit was swapped so add a tag and forward to swapped node
                        @debug "EntanglementTracker @$(prot.node): history=`$(history)` | message=`$msg` | Sending to $(whoweswappedwith_node).$(whoweswappedwith_slotidx)"
                        msghist = Tag(updatetagsymbol, pastremotenode, pastremoteslotid, whoweswappedwith_node, whoweswappedwith_slotidx)
                        tag!(localslot, updatetagsymbol, prot.node, localslot.idx, whoweswappedwith_node, whoweswappedwith_slotidx)
                        put!(channel(prot.net, prot.node=>whoweswappedwith_node; permit_forward=true), msghist)
                    end
                    continue
                end

                # Finally, if there the history of a swap is not present in the log anymore,
                # it must be because a delete message was received, and forwarded,
                # and the entanglement history was deleted, and replaced with an entanglement delete tag.
                if !isnothing(querydelete!(localslot, EntanglementDelete, prot.node, localslot.idx, pastremotenode, pastremoteslotid)) #deletion from both sides of the swap, deletion msg when both qubits of a pair are deleted, or when EU arrives after ED at swap node with two simultaneous swaps and deletion on one side
                    if !(isnothing(updategate)) # EntanglementUpdate
                        # to handle a possible delete-swap-swap case, we need to update the EntanglementDelete tag
                        tag!(localslot, EntanglementDelete, prot.node, localslot.idx, newremotenode, newremoteslotid)
                        @debug "EntanglementTracker @$(prot.node): message=`$msg` for deleted qubit handled and EntanglementDelete tag updated"
                    else # EntanglementDelete
                        # when the message is EntanglementDelete and the slot history also has an EntanglementDelete tag (both qubits were deleted), do nothing
                        @debug "EntanglementTracker @$(prot.node): message=`$msg` is for a deleted qubit and is thus dropped"
                    end
                    continue
                end

                error("`EntanglementTracker` on node $(prot.node) received a message $(msg) that it does not know how to handle (due to the absence of corresponding `EntanglementCounterpart` or `EntanglementHistory` or `EntanglementDelete` tags). This might have happened due to `CutoffProt` deleting qubits while swaps are happening. Make sure that the retention times in `CutoffProt` are sufficiently larger than the `agelimit` in `SwapperProt`. Otherwise, this is a bug in the protocol and should not happen -- please report an issue at QuantumSavory's repository.")
            end
        end
        @debug "EntanglementTracker @$(prot.node): Starting message wait at $(now(prot.sim)) with MessageBuffer containing: $(mb.buffer)"
        @yield wait(mb)
        @debug "EntanglementTracker @$(prot.node): Message wait ends at $(now(prot.sim))"
    end
end

"""
$TYPEDEF

A protocol running between two nodes, checking periodically for any entangled pairs between the two nodes and consuming/emptying the qubit slots.

$FIELDS
"""
@kwdef struct EntanglementConsumer{LT} <: AbstractProtocol where {LT<:Union{Float64,Nothing}}
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex index of node A"""
    nodeA::Int
    """the vertex index of node B"""
    nodeB::Int
    """time period between successive queries on the nodes (`nothing` for queuing up and waiting for available pairs)"""
    period::LT = 0.1
    """stores the time and resulting observable from querying nodeA and nodeB for `EntanglementCounterpart`"""
    log::Vector{Tuple{Float64, Float64, Float64}} = Tuple{Float64, Float64, Float64}[]
end

function EntanglementConsumer(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...)
    return EntanglementConsumer(;sim, net, nodeA, nodeB, kwargs...)
end
function EntanglementConsumer(net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...)
    return EntanglementConsumer(get_time_tracker(net), net, nodeA, nodeB; kwargs...)
end

@resumable function (prot::EntanglementConsumer)()
    if isnothing(prot.period)
        error("In `EntanglementConsumer` we do not yet support waiting on register to make qubits available") # TODO
    end
    while true
        query1 = query(prot.net[prot.nodeA], EntanglementCounterpart, prot.nodeB, ❓; locked=false, assigned=true) # TODO Need a `querydelete!` dispatch on `Register` rather than using `query` here followed by `untag!` below
        if isnothing(query1)
            @debug "EntanglementConsumer between $(prot.nodeA) and $(prot.nodeB): query on first node found no entanglement"
            @yield timeout(prot.sim, prot.period)
            continue
        else
            query2 = query(prot.net[prot.nodeB], EntanglementCounterpart, prot.nodeA, query1.slot.idx; locked=false, assigned=true)
            if isnothing(query2) # in case EntanglementUpdate hasn't reached the second node yet, but the first node has the EntanglementCounterpart
                @debug "EntanglementConsumer between $(prot.nodeA) and $(prot.nodeB): query on second node found no entanglement (yet...)"
                @yield timeout(prot.sim, prot.period)
                continue
            end
        end

        q1 = query1.slot
        q2 = query2.slot
        @yield lock(q1) & lock(q2)

        @debug "EntanglementConsumer between $(prot.nodeA) and $(prot.nodeB): queries successful, consuming entanglement between .$(q1.idx) and .$(q2.idx) @ $(now(prot.sim))"
        untag!(q1, query1.id)
        untag!(q2, query2.id)
        # TODO do we need to add EntanglementHistory or EntanglementDelete and should that be a different EntanglementHistory since the current one is specifically for Swapper
        # TODO currently when calculating the observable we assume that EntanglerProt.pairstate is always (|00⟩ + |11⟩)/√2, make it more general for other states
        ob1 = real(observable((q1, q2), Z⊗Z))
        ob2 = real(observable((q1, q2), X⊗X))

        traceout!(prot.net[prot.nodeA][q1.idx], prot.net[prot.nodeB][q2.idx])
        push!(prot.log, (now(prot.sim), ob1, ob2))
        unlock(q1)
        unlock(q2)
        @yield timeout(prot.sim, prot.period)
    end
end

"""
$TYPEDEF

A protocol running between two nodes, checking periodically for any entangled states (GHZ states) between all nodes and consuming/emptying the qubit slots.

$FIELDS
"""
@kwdef struct GHZConsumer{LT} <: AbstractProtocol where {LT<:Union{Float64,Nothing}}
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the piecemaker qubit slot"""
    piecemaker::RegRef
    """event when all users are sharing a ghz state"""
    event_ghz_state::Event
    """time period between successive queries on the nodes (`nothing` for queuing up and waiting for available pairs)"""
    period::LT = 0.1
    """stores the time and resulting observable from querying the piecemaker qubit for `EntanglementCounterpart`"""
    log::Vector{Tuple{Float64, Float64}} = Tuple{Float64, Float64}[]
end

function GHZConsumer(sim::Simulation, net::RegisterNet, piecemaker::RegRef, event_ghz_state::Event; kwargs...)
    return GHZConsumer(;sim, net, piecemaker,  event_ghz_state, kwargs...)
end
function GHZConsumer(net::RegisterNet, piecemaker::RegRef, event_ghz_state::Event; kwargs...)
    return GHZConsumer(get_time_tracker(net), net, piecemaker, event_ghz_state; kwargs...)
end

@resumable function (prot::GHZConsumer)()
    t_now = 0
    if isnothing(prot.period)
        error("In `GHZConsumer` we do not yet support waiting on register to make qubits available") # TODO
    end
    while true
        nclients = nsubsystems(prot.net[1])-1
        qparticipating = queryall(prot.piecemaker, FusionCounterpart, ❓, ❓) # TODO Need a `querydelete!` dispatch on `Register` rather than using `query` here followed by `untag!` below
        if isnothing(qparticipating)
            @debug "GHZConsumer between $(prot.piecemaker): query on piecemaker slot found no entanglement"
            @yield timeout(prot.sim, prot.period)
            return
        elseif length(qparticipating) == nclients
            @info "All clients are now part of the GHZ state."
            client_slots = [prot.net[k][1] for k in 2:nclients+1]
            
            # Wait for all locks to complete
            tasks = []
            for resource in client_slots
                push!(tasks, lock(resource))
            end
            push!(tasks, lock(prot.piecemaker))
            all_locks = reduce(&, tasks)
            @yield all_locks

            @debug "GHZConsumer of $(prot.piecemaker): queries successful, consuming entanglement"
            for q in qparticipating 
                untag!(prot.piecemaker, q.id)
            end

            # when all qubits have arrived, we measure out the central qubit
            zmeas = project_traceout!(prot.piecemaker, σˣ)
            if zmeas == 2
                apply!(prot.net[2][1], Z) # apply correction on arbitrary client slot
            end
            pm = queryall(prot.piecemaker, ❓, ❓, ❓)
            @assert length(pm) < 2 "More than one entry for piecemaker in database."
            (slot, id, tag) = pm[1]
            untag!(prot.piecemaker, id)

            result = real(observable(client_slots, projector(1/sqrt(2)*(reduce(⊗, [fill(Z1,nclients)...]) + reduce(⊗,[fill(Z2,nclients)...])))))
            @debug "GHZConsumer: expectation value $(result)" 
            
            # delete tags and free client slots
            for k in 2:nclients+1
                queries = queryall(prot.net[k], EntanglementCounterpart, ❓, ❓)
                for q in queries
                    untag!(q.slot, q.id)
                end
            end
            
            traceout!([prot.net[k][1] for k in 2:nclients+1]...)
            if t_now == 0
                push!(prot.log, (now(prot.sim), result,))
            else
                t_elapsed = now(prot.sim) - t_now
                push!(prot.log, (t_elapsed, result,))
            end
            t_now = now(prot.sim)

            for k in 2:nclients+1
                unlock(prot.net[k][1])
            end
            unlock(prot.piecemaker)
            
            succeed(prot.event_ghz_state)
            if state(prot.event_ghz_state) != idle
                throw(StopSimulation("GHZ state shared among all users!"))
            end
        end
        @yield timeout(prot.sim, prot.period)
    end
end

# """
# $TYPEDEF

# Helper function to return a random key of a dictionary.

# $TYPEDFIELDS
# """

# function random_index(arr)
#     return rand(keys(arr))
# end

"""
$TYPEDEF

A protocol, running at a given node, that finds fusable entangled pairs and performs entanglement fusion.

$TYPEDFIELDS
"""
@kwdef struct FusionProt{LT} <: AbstractProtocol where {LT<:Union{Float64,Nothing}}
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex of the node where fusion is happening"""
    node::Int
    """the vertex of the remote node for the fusion"""
    nodeC::Int
    """fixed "busy time" duration immediately before starting entanglement generation attempts"""
    local_busy_time::Float64 = 0.0 # TODO the gates should have that busy time built in
    """how long to wait before retrying to lock qubits if no qubits are available (`nothing` for queuing up and waiting)"""
    retry_lock_time::LT = 0.1
    """how many rounds of this protocol to run (`-1` for infinite))"""
    rounds::Int = -1
end

#TODO "convenience constructor for the missing things and finish this docstring"
function FusionProt(sim::Simulation, net::RegisterNet, node::Int; kwargs...)
    return FusionProt(;sim, net, node, kwargs...)
end

@resumable function (prot::FusionProt)()
    rounds = prot.rounds
    round = 1
    while rounds != 0
        fusable_qubit, piecemaker = findfusablequbit(prot.net, prot.node, prot.nodeC) # request client slots on switch node
        if isnothing(fusable_qubit)
            isnothing(prot.retry_lock_time) && error("We do not yet support waiting on register to make qubits available") # TODO
            @yield timeout(prot.sim, prot.retry_lock_time)
            continue
        end

        (q, id, tag) = fusable_qubit.slot, fusable_qubit.id, fusable_qubit.tag
        (q_pm, id_pm, tag_pm) = piecemaker.slot, piecemaker.id, piecemaker.tag
        @yield lock(q) & lock(q_pm) # this should not really need a yield thanks to `findswapablequbits`, but it is better to be defensive
        @yield timeout(prot.sim, prot.local_busy_time)

        untag!(q, id)
        # store a history of whom we were entangled to for both client slot and piecemaker
        tag!(q, EntanglementHistory, tag[2], tag[3], prot.node, q_pm.idx, q.idx)
        tag!(q_pm, FusionCounterpart, tag[2], tag[3])

        uptotime!((q, q_pm), now(prot.sim))
        fuscircuit = EntanglementFusion()
        zmeas = fuscircuit(q, q_pm) 
        # send from here to client node
        # tag with EntanglementUpdateX past_local_node, past_local_slot_idx, past_remote_slot_idx, new_remote_node, new_remote_slot, correction
        msg = Tag(EntanglementUpdateZ, prot.node, q.idx, tag[3], prot.node, q_pm.idx, zmeas)
        put!(channel(prot.net, prot.node=>tag[2]; permit_forward=true), msg)
        @debug "FusionProt @$(prot.node)|round $(round): Send message to $(tag[2]) | message=`$msg`"
        unlock(q)
        unlock(q_pm)
        rounds==-1 || (rounds -= 1)
        round += 1
    end
end

function findfusablequbit(net, node, pred_client)
    reg = net[node]
    nodes  = queryall(reg, EntanglementCounterpart, pred_client, ❓; locked=false)
    piecemaker = query(reg, Piecemaker, ❓, ❓)
    isempty(nodes) && return nothing
    @assert length(nodes) == 1 "Client seems to be entangled multiple times"
    return nodes[1], piecemaker
end

"""
$TYPEDEF

A protocol that generates entanglement between two nodes.
Whenever the selected client slot and the associated slot on the remote node are free, the protocol locks them
and starts probabilistic attempts to establish entanglement.

$TYPEDFIELDS
"""
@kwdef struct SelectedEntanglerProt{LT} <: AbstractProtocol where {LT<:Union{Float64,Nothing}}
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation # TODO check that
    """a network graph of registers"""
    net::RegisterNet
    """the vertex index of node A"""
    nodeA::Int
    """the vertex index of node B"""
    nodeB::Int
    """the state being generated (supports symbolic, numeric, noisy, and pure)"""
    pairstate = StabilizerState("ZZ XX")
    """success probability of one attempt of entanglement generation"""
    success_prob::Float64 = 0.001
    """duration of single entanglement attempt"""
    attempt_time::Float64 = 0.001
    """fixed "busy time" duration immediately before starting entanglement generation attempts"""
    local_busy_time_pre::Float64 = 0.0
    """fixed "busy time" duration immediately after the a successful entanglement generation attempt"""
    local_busy_time_post::Float64 = 0.0
    """how long to wait before retrying to lock qubits if no qubits are available (`nothing` for queuing up)"""
    retry_lock_time::LT = 0.1
    """how many rounds of this protocol to run (`-1` for infinite)"""
    rounds::Int = -1
    """maximum number of attempts to make per round (`-1` for infinite)"""
    attempts::Int = -1
    """whether the protocol should find the first available free slots in the nodes to be entangled or check for free slots randomly from the available slots"""
    randomize::Bool = false
    """Repeated rounds of this protocol may lead to monopolizing all slots of a pair of registers, starving or deadlocking other protocols. This field can be used to always leave a minimum number of slots free if there already exists entanglement between the current pair of nodes."""
    margin::Int = 0
    """Like `margin`, but it is enforced even when no entanglement has been established yet. Usually smaller than `margin`."""
    hardmargin::Int = 0
end

"""Convenience constructor for specifying `rate` of generation instead of success probability and time"""
function SelectedEntanglerProt(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int; rate::Union{Nothing,Float64}=nothing, kwargs...)
    if isnothing(rate)
        return SelectedEntanglerProt(;sim, net, nodeA, nodeB, kwargs...)
    else
        return SelectedEntanglerProt(;sim, net, nodeA, nodeB, kwargs..., success_prob=0.001, attempt_time=0.001/rate)
    end
end

#TODO """Convenience constructor for specifying `fidelity` of generation instead of success probability and time"""

@resumable function (prot::SelectedEntanglerProt)()
    rounds = prot.rounds
    round = 1
    while rounds != 0
        isentangled = !isnothing(query(prot.net[prot.nodeA], EntanglementCounterpart, prot.nodeB, ❓; assigned=true))
        a = prot.net[prot.nodeA][prot.nodeB-1] 
        b = prot.net[prot.nodeB][1]

        if isnothing(a) || isnothing(b)
            isnothing(prot.retry_lock_time) && error("We do not yet support waiting on register to make qubits available") # TODO
            @debug "EntanglerProt between $(prot.nodeA) and $(prot.nodeB)|round $(round): Failed to find free slots. \nGot:\n1. \t $a \n2.\t $b \n retrying..."
            #@yield timeout(prot.sim, prot.retry_lock_time)
            continue
        end

        @yield lock(a) & lock(b) # this yield is expected to return immediately

        #@yield timeout(prot.sim, prot.local_busy_time_pre)
        attempts = if isone(prot.success_prob)
            1
        else
            rand(Geometric(prot.success_prob))+1
        end

        if (prot.attempts == -1 || prot.attempts >= attempts) && !isassigned(b) && !isassigned(a)
            @yield timeout(prot.sim, attempts * prot.attempt_time)
            initialize!((a,b), prot.pairstate; time=now(prot.sim))
            #@yield timeout(prot.sim, prot.local_busy_time_post)

            # tag local node a with EntanglementCounterpart remote_node_idx_b remote_slot_idx_b
            tag!(a, EntanglementCounterpart, prot.nodeB, b.idx)
            # tag local node b with EntanglementCounterpart remote_node_idx_a remote_slot_idx_a
            tag!(b, EntanglementCounterpart, prot.nodeA, a.idx)

            @debug "EntanglerProt between $(prot.nodeA) and $(prot.nodeB)|round $(round): Entangled .$(a.idx) and .$(b.idx)"
        else
            @yield timeout(prot.sim, prot.attempts * prot.attempt_time)
            @debug "EntanglerProt between $(prot.nodeA) and $(prot.nodeB)|round $(round): Performed the maximum number of attempts and gave up"
        end
        unlock(a)
        unlock(b)
        #@yield timeout(prot.sim, prot.retry_lock_time)
        rounds==-1 || (rounds -= 1)
        round += 1
    end
end


include("cutoff.jl")
include("swapping.jl")
include("switches.jl")
using .Switches

end # module
