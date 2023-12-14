module ProtocolZoo

using QuantumSavory
import QuantumSavory: get_time_tracker, Tag
using QuantumSavory: Wildcard
using QuantumSavory.CircuitZoo: EntanglementSwap, LocalEntanglementSwap

using DocStringExtensions

using Distributions: Geometric
using ConcurrentSim: Simulation, @yield, timeout, @process, now
import ConcurrentSim: Process
import ResumableFunctions
using ResumableFunctions: @resumable
import SumTypes

export EntanglerProt, SwapperProt, EntanglementTracker

abstract type AbstractProtocol end

get_time_tracker(prot::AbstractProtocol) = prot.sim

Process(prot::AbstractProtocol, args...; kwargs...) = Process((e,a...;k...)->prot(a...;k...,_prot=prot), get_time_tracker(prot), args...; kwargs...)

@kwdef struct EntanglementCounterpart
    remote_node::Int
    remote_slot::Int
end
Base.show(io::IO, tag::EntanglementCounterpart) = print(io, "Entangled to $(tag.remote_node).$(tag.remote_slot)")
Tag(tag::EntanglementCounterpart) = Tag(EntanglementCounterpart, tag.remote_node, tag.remote_slot)

@kwdef struct EntanglementHistory
    remote_node::Int
    remote_slot::Int
    swap_remote_node::Int
    swap_remote_slot::Int
    swapped_local::Int
end
Base.show(io::IO, tag::EntanglementHistory) = print(io, "Was entangled to $(tag.remote_node).$(tag.remote_slot), but swapped with .$(tag.swapped_local) which was entangled to $(tag.swap_remote_node).$(tag.swap_remote_slot)")
Tag(tag::EntanglementHistory) = Tag(EntanglementHistory, tag.remote_node, tag.remote_slot, tag.swap_remote_node, tag.swap_remote_slot, tag.swapped_local)

@kwdef struct EntanglementUpdateX
    past_local_node::Int
    past_local_slot::Int
    past_remote_slot::Int
    new_remote_node::Int
    new_remote_slot::Int
    correction::Int
end
Base.show(io::IO, tag::EntanglementUpdateX) = print(io, "Update slot .$(tag.past_remote_slot) which used to be entangled to $(tag.past_local_node).$(tag.past_local_slot) to be entangled to $(tag.new_remote_node).$(tag.new_remote_slot) and apply correction X$(tag.correction)")
Tag(tag::EntanglementUpdateX) = Tag(EntanglementUpdateX, tag.past_local_node, tag.past_local_slot, tag.past_remote_slot, tag.new_remote_node, tag.new_remote_slot, tag.correction)

@kwdef struct EntanglementUpdateZ
    past_local_node::Int
    past_local_slot::Int
    past_remote_slot::Int
    new_remote_node::Int
    new_remote_slot::Int
    correction::Int
end
Base.show(io::IO, tag::EntanglementUpdateZ) = print(io, "Update slot .$(tag.past_remote_slot) which used to be entangled to $(tag.past_local_node).$(tag.past_local_slot) to be entangled to $(tag.new_remote_node).$(tag.new_remote_slot) and apply correction Z$(tag.correction)")
Tag(tag::EntanglementUpdateZ) = Tag(EntanglementUpdateZ, tag.past_local_node, tag.past_local_slot, tag.past_remote_slot, tag.new_remote_node, tag.new_remote_slot, tag.correction)

"""
$TYPEDEF

A protocol that generates entanglement between two nodes.
Whenever a pair of empty slots is available, the protocol locks them
and starts probabilistic attempts to establish entanglement.

$FIELDS
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
    """how many rounds of this protocol to run (`-1` for infinite))"""
    rounds::Int = -1
    """whether the protocol should find the first available free slots in the nodes to be entangled or check for free slots randomly from the available slots"""
    randomize::Bool = false
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

@resumable function (prot::EntanglerProt)(;_prot::EntanglerProt=prot)
    prot = _prot # weird workaround for no support for `struct A a::Int end; @resumable function (fa::A) return fa.a end`; see https://github.com/JuliaDynamics/ResumableFunctions.jl/issues/77
    rounds = prot.rounds
    while rounds != 0
        a = findfreeslot(prot.net[prot.nodeA], randomize=prot.randomize)
        b = findfreeslot(prot.net[prot.nodeB], randomize=prot.randomize)
        if isnothing(a) || isnothing(b)
            isnothing(prot.retry_lock_time) && error("We do not yet support waiting on register to make qubits available") # TODO
            @yield timeout(prot.sim, prot.retry_lock_time)
            continue
        end

        @yield lock(a) & lock(b) # this yield is expected to return immediately

        @yield timeout(prot.sim, prot.local_busy_time_pre)
        @yield timeout(prot.sim, (rand(Geometric(prot.success_prob))+1) * prot.attempt_time)
        initialize!((a,b), prot.pairstate; time=now(prot.sim))
        @yield timeout(prot.sim, prot.local_busy_time_post)

        # tag local node a with EntanglementCounterpart remote_node_idx_b remote_slot_idx_b
        tag!(a, EntanglementCounterpart, prot.nodeB, b.idx)
        # tag local node b with EntanglementCounterpart remote_node_idx_a remote_slot_idx_a
        tag!(b, EntanglementCounterpart, prot.nodeA, a.idx)

        unlock(a)
        unlock(b)
        rounds==-1 || (rounds -= 1)
    end
end


"""
$TYPEDEF

A protocol, running at a given node, that finds swappable entangled pairs and performs the swap.

$FIELDS
"""
@kwdef struct SwapperProt{L,R,LT} <: AbstractProtocol where {L<:Union{Int,<:Function,Wildcard}, R<:Union{Int,<:Function,Wildcard}, LT<:Union{Float64,Nothing}}
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex of the node where swapping is happening"""
    node::Int
    """the vertex of one of the remote nodes (or a predicate function or a wildcard)"""
    nodeL::L = ❓
    """the vertex of the other remote node (or a predicate function or a wildcard)"""
    nodeR::R = ❓
    """fixed "busy time" duration immediately before starting entanglement generation attempts"""
    local_busy_time::Float64 = 0.0 # TODO the gates should have that busy time built in
    """how long to wait before retrying to lock qubits if no qubits are available (`nothing` for queuing up and waiting)"""
    retry_lock_time::LT = 0.1
    """how many rounds of this protocol to run (`-1` for infinite))"""
    rounds::Int = -1
end

#TODO "convenience constructor for the missing things and finish this docstring"
function SwapperProt(sim::Simulation, net::RegisterNet, node::Int; kwargs...)
    return SwapperProt(;sim, net, node, kwargs...)
end

@resumable function (prot::SwapperProt)(;_prot::SwapperProt=prot)
    prot = _prot # weird workaround for no support for `struct A a::Int end; @resumable function (fa::A) return fa.a end`; see https://github.com/JuliaDynamics/ResumableFunctions.jl/issues/77
    rounds = prot.rounds
    while rounds != 0
        reg = prot.net[prot.node]
        qubit_pair = findswapablequbits(prot.net,prot.node)
        if isnothing(qubit_pair)
            isnothing(prot.retry_lock_time) && error("We do not yet support waiting on register to make qubits available") # TODO
            @yield timeout(prot.sim, prot.retry_lock_time)
            continue
        end
        (q1, tag1), (q2, tag2) = qubit_pair
        @yield lock(q1) & lock(q2) # this should not really need a yield thanks to `findswapablequbits`, but it is better to be defensive
        @yield timeout(prot.sim, prot.local_busy_time)

        untag!(q1, tag1)
        # store a history of whom we were entangled to: remote_node_idx, remote_slot_idx, remote_swapnode_idx, remote_swapslot_idx, local_swap_idx
        tag!(q1, EntanglementHistory, tag1[2], tag1[3], tag2[2], tag2[3], q2.idx)

        untag!(q2, tag2)
        # store a history of whom we were entangled to: remote_node_idx, remote_slot_idx, remote_swapnode_idx, remote_swapslot_idx, local_swap_idx
        tag!(q2, EntanglementHistory, tag2[2], tag2[3], tag1[2], tag1[3], q1.idx)

        uptotime!((q1, q2), now(prot.sim))
        swapcircuit = LocalEntanglementSwap()
        xmeas, zmeas = swapcircuit(q1, q2)
        # send from here to new entanglement counterpart:
        # tag with EntanglementUpdateX past_local_node, past_local_slot_idx past_remote_slot_idx new_remote_node, new_remote_slot, correction
        msg1 = Tag(EntanglementUpdateX, prot.node, q1.idx, tag1[3], tag2[2], tag2[3], xmeas)
        put!(channel(prot.net, prot.node=>tag1[2]; permit_forward=true), msg1)
        @debug "SwapperProt @$(prot.node): Send message to $(tag1[2]) | message=`$msg1`"
        # send from here to new entanglement counterpart:
        # tag with EntanglementUpdateZ past_local_node, past_local_slot_idx past_remote_slot_idx new_remote_node, new_remote_slot, correction
        msg2 = Tag(EntanglementUpdateZ, prot.node, q2.idx, tag2[3], tag1[2], tag1[3], zmeas)
        put!(channel(prot.net, prot.node=>tag2[2]; permit_forward=true), msg2)
        @debug "SwapperProt @$(prot.node): Send message to $(tag2[2]) | message=`$msg2`"
        unlock(q1)
        unlock(q2)
        rounds==-1 || (rounds -= 1)
    end
end

function findswapablequbits(net,node) # TODO parameterize the query predicates and the findmin/findmax
    reg = net[node]

    leftnodes  = queryall(reg, EntanglementCounterpart, <(node), ❓; locked=false, assigned=true)
    rightnodes = queryall(reg, EntanglementCounterpart, >(node), ❓; locked=false, assigned=true)

    (isempty(leftnodes) || isempty(rightnodes)) && return nothing
    _, il = findmin(n->n.tag[2], leftnodes) # TODO make [2] into a nice named property
    _, ir = findmax(n->n.tag[2], rightnodes)
    return leftnodes[il], rightnodes[ir]
end


"""
$TYPEDEF

A protocol, running at a given node, listening for messages that indicate something has happened to a remote qubit entangled with one of the local qubits.

$FIELDS
"""
@kwdef struct EntanglementTracker <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex of the node where the tracker is working"""
    node::Int
end

@resumable function (prot::EntanglementTracker)(;_prot::EntanglementTracker=prot)
    prot = _prot # weird workaround for no support for `struct A a::Int end; @resumable function (fa::A) return fa.a end`; see https://github.com/JuliaDynamics/ResumableFunctions.jl/issues/77
    nodereg = prot.net[prot.node]
    mb = messagebuffer(prot.net, prot.node)
    while true
        workwasdone = true # waiting is not enough because we might have multiple rounds of work to do
        while workwasdone
            workwasdone = false
            for (updatetagsymbol, updategate) in ((EntanglementUpdateX, X), (EntanglementUpdateZ, Z))
                # look for EntanglementUpdate? past_remote_slot_idx local_slot_idx, new_remote_node, new_remote_slot_idx correction
                msg = querydelete!(mb, updatetagsymbol, ❓, ❓, ❓, ❓, ❓, ❓)
                isnothing(msg) && continue
                @debug "EntanglementTracker @$(prot.node): Received from $(msg.src).$(msg.tag[3]) | message=`$(msg.tag)`"
                workwasdone = true
                (src, (_, pastremotenode, pastremoteslotid, localslotid, newremotenode, newremoteslotid, correction)) = msg
                localslot = nodereg[localslotid]
                # Check if the local slot is still present and believed to be entangled.
                # We will need to perform a correction operation due to the swap,
                # but there will be no message forwarding necessary.
                counterpart = querydelete!(localslot, EntanglementCounterpart, pastremotenode, pastremoteslotid)
                if !isnothing(counterpart)
                    time_before_lock = now(prot.sim)
                    @debug "EntanglementTracker @$(prot.node): EntanglementCounterpart requesting lock at $(now(prot.sim))"
                    @yield lock(localslot)
                    @debug "EntanglementTracker @$(prot.node): EntanglementCounterpart getting lock at $(now(prot.sim))"
                    time_after_lock = now(prot.sim)
                    time_before_lock != time_after_lock && @debug "EntanglementTracker @$(prot.node): Needed Δt=$(time_after_lock-time_before_lock) to get a lock"
                    if !isassigned(localslot)
                        unlock(localslot)
                        error("There was an error in the entanglement tracking protocol `EntanglementTracker`. We were attempting to forward a classical message from a node that performed a swap to the remote entangled node. However, on reception of that message it was found that the remote node has lost track of its part of the entangled state although it still keeps a `Tag` as a record of it being present.")
                    end
                    # TODO correction gate
                    # tag local with updated EntanglementCounterpart new_remote_node new_remote_slot_idx
                    tag!(localslot, EntanglementCounterpart, newremotenode, newremoteslotid)
                    unlock(localslot)
                    continue
                end
                # If not, check if we have a record of the entanglement being swapped to a different remote node,
                # and forward the message to that node.
                history = querydelete!(localslot, EntanglementHistory,
                                    pastremotenode, pastremoteslotid, # who we were entangled to (node, slot)
                                    ❓, ❓,                             # who we swapped with (node, slot)
                                    ❓)                                # which local slot used to be entangled with whom we swapped with
                if !isnothing(history)
                    # @debug "tracker @$(prot.node) history: $(history) | msg: $msg"
                    _, _, _, whoweswappedwith_node, whoweswappedwith_slotidx, swappedlocal_slotidx = history
                    tag!(localslot, EntanglementHistory, newremotenode, newremoteslotid, whoweswappedwith_node, whoweswappedwith_slotidx, swappedlocal_slotidx)
                    @debug "EntanglementTracker @$(prot.node): history=`$(history)` | message=`$msg` | Sending to $(whoweswappedwith_node).$(whoweswappedwith_slotidx)"
                    msghist = Tag(updatetagsymbol, pastremotenode, pastremoteslotid, whoweswappedwith_slotidx, newremotenode, newremoteslotid, correction)
                    put!(channel(prot.net, prot.node=>whoweswappedwith_node; permit_forward=true), msghist)
                    #println("           history sends to $whoweswappedwith_node: ", msghist)
                    continue
                end
                error("`EntanglementTracker` on node $(prot.node) received a message $(msg) that it does not know how to handle (due to the absence of corresponding `EntanglementCounterpart` or `EntanglementHistory` tags). This is a bug in the protocol and should not happen -- please report an issue at QuantumSavory's repository.")
            end
        end
        @debug "EntanglementTracker @$(prot.node): Starting message wait at $(now(prot.sim)) with MessageBuffer containing: $(mb.buffer)"
        @yield wait(mb)
        @debug "EntanglementTracker @$(prot.node): Message wait ends at $(now(prot.sim))"
    end
end

end # module
