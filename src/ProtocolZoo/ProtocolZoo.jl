module ProtocolZoo

using QuantumSavory
import QuantumSavory: get_time_tracker, Tag, isolderthan
using QuantumSavory: Wildcard
using QuantumSavory.CircuitZoo: EntanglementSwap, LocalEntanglementSwap

using DocStringExtensions

using Distributions: Geometric, Exponential
using ConcurrentSim: Simulation, @yield, timeout, @process, now
import ConcurrentSim: Process
import ResumableFunctions
using ResumableFunctions: @resumable
import SumTypes
using Graphs
using Memoize

export
    # protocols
    EntanglerProt, SwapperProt, EntanglementTracker, EntanglementConsumer, CutoffProt, RequestTracker, RequestGeneratorCO, RequestGeneratorCL,
    # tags
    EntanglementCounterpart, EntanglementHistory, EntanglementUpdateX, EntanglementUpdateZ, EntanglementRequest, SwapRequest, DistributionRequest,
    # from Switches
    SimpleSwitchDiscreteProt, SwitchRequest,
    # controllers
    NetController, Controller, CLController,
    #utils
    PathMetadata, path_selection, swap_predicate, swap_choose

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

A message sent from a controller to the [`RequestTracker`](@ref) at a node requesting the generation of an entanglement link between the receiving node
and one of its next-hop neighbors on the physical graph, as mentioned in the request

$TYPEDFIELDS

See also: [EntanglerProt](@ref), [`EntanglementTracker`](@ref), [`SwapRequest`](@ref)
"""
@kwdef struct EntanglementRequest
    "The id of the node receiving the request"
    receiver::Int
    "The id of the node with which the entanglement link should be established"
    neighbor::Int
    "The number of rounds the Entangler should run for"
    rounds::Int
end
Base.show(io::IO, tag::EntanglementRequest) = print(io, "$(tag.receiver) attempt entanglement generation with $(tag.neighbor)")
Tag(tag::EntanglementRequest) = Tag(EntanglementRequest, tag.receiver, tag.neighbor, tag.rounds)

"""
$TYPEDEF

A message sent from a controller to the [`RequestTracker`](@ref) at a node requesting it to perform a swap

$TYPEDFIELDS

See also: [`SwapperProt`](@ref), [`EntanglementTracker`](@ref), [`EntanglementRequest`](@ref)
"""
@kwdef struct SwapRequest
    """The id of the node instructed to perform a swap"""
    swapping_node::Int
    """The number of rounds the swapper should run for"""
    rounds::Int
    """source node for the `DistributionRequest`"""
    src::Int
    """destination node for the `DistributionRequest`"""
    dst::Int
    """whether the request is from a connection-oriented(0) or connection-less controller(1)"""
    conn::Int
end
Base.show(io::IO, tag::SwapRequest) = print(io, "Node $(tag.swapping_node) perform a swap")
Tag(tag::SwapRequest) = Tag(SwapRequest, tag.swapping_node, tag.rounds, tag.src, tag.dst)

"""
$TYPEDEF

A message sent from a node to a control protocol requesting bipartite entanglement with a remote destination node through entanglement distribution. 

$TYPEDFIELDS

See also: [`EntanglementRequest`](@ref), [`SwapRequest`]
"""
@kwdef struct DistributionRequest
    """The node generating the request"""
    src::Int
    """The node with which entanglement is to be generated"""
    dst::Int
    """The number of rounds of swaps requested"""
    rounds::Int = 1
end
Base.show(io::IO, tag::DistributionRequest) = print(io, "Node $(tag.src) requesting entanglement with $(tag.dst)")
Tag(tag::DistributionRequest) = Tag(DistributionRequest, tag.src, tag.dst, tag.rounds)


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

$TYPEDFIELDS
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

A protocol running at a node, listening for incoming entanglement generation and swap requests and serving
them in an asynchronous way, without waiting for the completion of the instantiated entanglement generation or swapping processes to complete

$TYPEDFIELDS
"""
@kwdef struct RequestTracker <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex of the node where the tracker is working"""
    node::Int
end

@resumable function (prot::RequestTracker)()
    mb = messagebuffer(prot.net, prot.node)
    while true
        workwasdone = true # waiting is not enough because we might have multiple rounds of work to do
        while workwasdone
            workwasdone = false # if there is nothing in the mb queue(querydelete returns nothing) we skip to waiting, otherwise we keep querying until the queue is empty
            for requesttagsymbol in (EntanglementRequest, SwapRequest)
                if requesttagsymbol == EntanglementRequest
                    msg = querydelete!(mb, requesttagsymbol, ❓, ❓, ❓)
                    @debug "RequestTracker @$(prot.node): Received $msg"
                    isnothing(msg) && continue
                    workwasdone = true
                    (src, (_, _, neighbor, rounds)) = msg
                    @debug "RequestTracker @$(prot.node): Generating entanglement with $(neighbor)"
                    entangler = EntanglerProt(prot.sim, prot.net, prot.node, neighbor; rounds=rounds, randomize=true)
                    @process entangler()
                else
                    msg = querydelete!(mb, requesttagsymbol, ❓, ❓, ❓, ❓, ❓)
                    @debug "RequestTracker @$(prot.node): Received $msg"
                    isnothing(msg) && continue
                    workwasdone = true
                    (msg_src, (_, _, rounds, req_src, req_dst, conn)) = msg
                    @debug "RequestTracker @$(prot.node): Performing a swap"
                    if conn == 0 # connection-oriented
                        swapper = SwapperProt(prot.sim, prot.net, prot.node; nodeL = req_src, nodeH = req_dst, rounds=rounds)
                        @process swapper()
                    else # connection-less
                        pred_low = swap_predicate(prot.net.graph, req_src, req_dst, prot.node)
                        pred_high = swap_predicate(prot.net.graph, req_src, req_dst, prot.node; low=false)
                        choose_low = swap_choose(prot.net.graph, req_src)
                        choose_high = swap_choose(prot.net.graph, req_dst)
                        swapper = SwapperProt(prot.sim, prot.net, prot.node; nodeL = pred_low, nodeH = pred_high, chooseL=choose_low, chooseH=choose_high, rounds=rounds)
                        @process swapper()
                    end
                end
            end
        end
        @debug "RequestTracker @$(prot.node): Starting message wait at $(now(prot.sim)) with MessageBuffer containing: $(mb.buffer)"
        @yield wait(mb)
        @debug "RequestTracker @$(prot.node): Message wait ends at $(now(prot.sim))"
    end
end

include("utils.jl")

"""
$TYPEDEF

Protocol for the simulation of request traffic for a controller in a connection-oriented network for bipartite entanglement distribution. The requests are considered to be generated according to the Poisson model with rate λ, hence the inter-arrival time is
sampled from an exponential distribution. Physically, the request is generated at the source node(Alice) and is classically communicated to the node where the controller is located. Multiple `RequestGenerator`s can be instantiated for simulation with multiple
user pairs in the same network.

$TYPEDFIELDS
"""
@kwdef struct RequestGeneratorCO <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """The source node(and the node where this protocol runs) of the user pair, commonly called Alice"""
    src::Int
    """The destination node, commonly called Bob"""
    dst::Int
    """The node at which the controller is located"""
    controller::Int
    """rate of arrival of requests/number of requests sent unit time"""
    λ::Int = 3
end

function RequestGeneratorCO(sim, net, src, dst, controller; kwargs...)
    return RequestGeneratorCO(;sim, net, src, dst, controller, kwargs...)
end

@resumable function (prot::RequestGeneratorCO)()
    d = Exponential(inv(prot.λ)) # Parametrized with the scale which is inverse of the rate
    mb = messagebuffer(prot.net, prot.src)
    while true
        msg = Tag(DistributionRequest, prot.src, prot.dst, 1)
        put!(channel(prot.net, prot.src=>prot.controller; permit_forward=true), msg)

        @yield timeout(prot.sim, rand(d))
    end
end


"""
$TYPEDEF

Protocol for the simulation of request traffic for a controller in a connection-oriented network for bipartite entanglement distribution. The requests are considered to be generated according to the Poisson model with rate λ, hence the inter-arrival time is
sampled from an exponential distribution. Physically, the request is generated at the source node(Alice) and is classically communicated to the node where the controller is located. Multiple `RequestGenerator`s can be instantiated for simulation with multiple
user pairs in the same network.

$TYPEDFIELDS
"""
@kwdef struct RequestGeneratorCL <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """The source node(and the node where this protocol runs) of the user pair, commonly called Alice"""
    src::Int
    """The destination node, commonly called Bob"""
    dst::Int
    """The node at which the controller is located"""
    controller::Int
    """The number of rounds of swaps to be requested, -1 for infinite"""
    rounds::Int = -1
end

function RequestGeneratorCL(sim, net, src, dst, controller; kwargs...)
    return RequestGeneratorCL(;sim, net, src, dst, controller, kwargs...)
end

@resumable function (prot::RequestGeneratorCL)()
    mb = messagebuffer(prot.net, prot.src)
    msg = Tag(DistributionRequest, prot.src, prot.dst, prot.rounds)
    put!(channel(prot.net, prot.src=>prot.controller; permit_forward=true), msg)
end


include("cutoff.jl")
include("swapping.jl")
include("controllers.jl")
include("switches.jl")
using .Switches

end # module
