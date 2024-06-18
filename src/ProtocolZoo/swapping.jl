function random_index(arr)
    return rand(keys(arr))
end

"""
$TYPEDEF

A protocol, running at a given node, that finds swappable entangled pairs and performs the swap. If the decoherence prtocol, [`DecoherenceProt`](@ref) is used, then communications about the 
decoherence status of qubit would be done with asynchronous messaging through the [`EntanglementTracker`](@ref). Thus, `SwapperKeeper` keeps(considers) all the swap candidates
without verifying their decoherence status, leaving it to the [`EntanglementTracker`](@ref) to handle deletions performed by the decoherence protocol and forwarding the deletion messages
to the swapped nodes after the swap.

See also: [`SwapperShedder`](@ref)

$TYPEDFIELDS
"""
@kwdef struct SwapperKeeper{NL,NH,CL,CH,LT} <: AbstractProtocol where {NL<:Union{Int,<:Function,Wildcard}, NH<:Union{Int,<:Function,Wildcard}, CL<:Function, CH<:Function, LT<:Union{Float64,Nothing}}
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex of the node where swapping is happening"""
    node::Int
    """the vertex of one of the remote nodes for the swap, arbitrarily referred to as the "low" node (or a predicate function or a wildcard); if you are working on a repeater chain, a good choice is `<(current_node)`, i.e. any node to the "left" of the current node"""
    nodeL::NL = ❓
    """the vertex of the other remote node for the swap, the "high" counterpart of `nodeL`; if you are working on a repeater chain, a good choice is `>(current_node)`, i.e. any node to the "right" of the current node"""
    nodeH::NH = ❓
    """the `nodeL` predicate can return many positive candidates; `chooseL` picks one of them (by index into the array of filtered `nodeL` results), defaults to a random pick `arr->rand(keys(arr))`; if you are working on a repeater chain a good choice is `argmin`, i.e. the node furthest to the "left" """
    chooseL::CL = random_index
    """the `nodeH` counterpart for `chooseH`; if you are working on a repeater chain a good choice is `argmax`, i.e. the node furthest to the "right" """
    chooseH::CH = random_index
    """fixed "busy time" duration immediately before starting entanglement generation attempts"""
    local_busy_time::Float64 = 0.0 # TODO the gates should have that busy time built in
    """how long to wait before retrying to lock qubits if no qubits are available (`nothing` for queuing up and waiting)"""
    retry_lock_time::LT = 0.1
    """how many rounds of this protocol to run (`-1` for infinite))"""
    rounds::Int = -1
end

#TODO "convenience constructor for the missing things and finish this docstring"
function SwapperKeeper(sim::Simulation, net::RegisterNet, node::Int; kwargs...)
    return SwapperKeeper(;sim, net, node, kwargs...)
end

@resumable function (prot::SwapperKeeper)()
    rounds = prot.rounds
    round = 1
    while rounds != 0
        qubit_pair = findswapablequbits(prot.net, prot.node, prot.nodeL, prot.nodeH, prot.chooseL, prot.chooseH)
        if isnothing(qubit_pair)
            isnothing(prot.retry_lock_time) && error("We do not yet support waiting on register to make qubits available") # TODO
            @yield timeout(prot.sim, prot.retry_lock_time)
            continue
        end

        (q1, id1, tag1) = qubit_pair[1].slot, qubit_pair[1].id, qubit_pair[1].tag
        (q2, id2, tag2) = qubit_pair[2].slot, qubit_pair[2].id, qubit_pair[2].tag
        untag!(q1, id1)
        untag!(q2, id2)
        @yield lock(q1) & lock(q2) # this should not really need a yield thanks to `findswapablequbits`, but it is better to be defensive
        @yield timeout(prot.sim, prot.local_busy_time)

        # store a history of whom we were entangled to: remote_node_idx, remote_slot_idx, remote_swapnode_idx, remote_swapslot_idx, local_swap_idx
        tag!(q1, EntanglementHistory, tag1[2], tag1[3], tag2[2], tag2[3], q2.idx)

        # store a history of whom we were entangled to: remote_node_idx, remote_slot_idx, remote_swapnode_idx, remote_swapslot_idx, local_swap_idx
        tag!(q2, EntanglementHistory, tag2[2], tag2[3], tag1[2], tag1[3], q1.idx)

        uptotime!((q1, q2), now(prot.sim))
        swapcircuit = LocalEntanglementSwap()
        xmeas, zmeas = swapcircuit(q1, q2)
        # send from here to new entanglement counterpart:
        # tag with EntanglementUpdateX past_local_node, past_local_slot_idx past_remote_slot_idx new_remote_node, new_remote_slot, correction
        msg1 = Tag(EntanglementUpdateX, prot.node, q1.idx, tag1[3], tag2[2], tag2[3], xmeas)
        put!(channel(prot.net, prot.node=>tag1[2]; permit_forward=true), msg1)
        @debug "SwapperKeeper @$(prot.node)|round $(round): Send message to $(tag1[2]) | message=`$msg1` | time = $(now(prot.sim))"
        # send from here to new entanglement counterpart:
        # tag with EntanglementUpdateZ past_local_node, past_local_slot_idx past_remote_slot_idx new_remote_node, new_remote_slot, correction
        msg2 = Tag(EntanglementUpdateZ, prot.node, q2.idx, tag2[3], tag1[2], tag1[3], zmeas)
        put!(channel(prot.net, prot.node=>tag2[2]; permit_forward=true), msg2)
        @debug "SwapperKeeper @$(prot.node)|round $(round): Send message to $(tag2[2]) | message=`$msg2` | time = $(now(prot.sim))"
        unlock(q1)
        unlock(q2)
        rounds==-1 || (rounds -= 1)
        round += 1
    end
end

function findswapablequbits(net, node, pred_low, pred_high, choose_low, choose_high; sync=false, buffer_time=nothing, retention_time=nothing)
    reg = net[node]
    low_nodes  = [n for n in queryall(reg, EntanglementCounterpart, pred_low, ❓; locked=false, assigned=true) if !(sync)||!isolderthan(n.slot, retention_time-buffer_time)]
    high_nodes = [n for n in queryall(reg, EntanglementCounterpart, pred_high, ❓; locked=false, assigned=true) if !(sync)||!isolderthan(n.slot, retention_time-buffer_time)]

    (isempty(low_nodes) || isempty(high_nodes)) && return nothing
    il = choose_low((n.tag[2] for n in low_nodes)) # TODO make [2] into a nice named property
    ih = choose_high((n.tag[2] for n in high_nodes))
    return (low_nodes[il], high_nodes[ih])
end

"""
$TYPEDEF

A protocol, running at a given node, that finds swappable entangled pairs and performs the swap.
Rejects the swap candidates that are about to decohere by checking their time of creation, while the decoherence protocol, [`DecoherenceProt`](@ref) deletes such qubits independently.

See also: [`SwapperKeeper`](@ref)


$TYPEDFIELDS
"""
@kwdef struct SwapperShedder{NL,NH,CL,CH,LT} <: AbstractProtocol where {NL<:Union{Int,<:Function,Wildcard}, NH<:Union{Int,<:Function,Wildcard}, CL<:Function, CH<:Function, LT<:Union{Float64,Nothing}}
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex of the node where swapping is happening"""
    node::Int
    """the vertex of one of the remote nodes for the swap, arbitrarily referred to as the "low" node (or a predicate function or a wildcard); if you are working on a repeater chain, a good choice is `<(current_node)`, i.e. any node to the "left" of the current node"""
    nodeL::NL = ❓
    """the vertex of the other remote node for the swap, the "high" counterpart of `nodeL`; if you are working on a repeater chain, a good choice is `>(current_node)`, i.e. any node to the "right" of the current node"""
    nodeH::NH = ❓
    """the `nodeL` predicate can return many positive candidates; `chooseL` picks one of them (by index into the array of filtered `nodeL` results), defaults to a random pick `arr->rand(keys(arr))`; if you are working on a repeater chain a good choice is `argmin`, i.e. the node furthest to the "left" """
    chooseL::CL = random_index
    """the `nodeH` counterpart for `chooseH`; if you are working on a repeater chain a good choice is `argmax`, i.e. the node furthest to the "right" """
    chooseH::CH = random_index
    """fixed "busy time" duration immediately before starting entanglement generation attempts"""
    local_busy_time::Float64 = 0.0 # TODO the gates should have that busy time built in
    """how long to wait before retrying to lock qubits if no qubits are available (`nothing` for queuing up and waiting)"""
    retry_lock_time::LT = 0.1
    """how many rounds of this protocol to run (`-1` for infinite))"""
    rounds::Int = -1
    """what is the oldest a qubit should be to be picked for a swap"""
    retention_time::Float64 = 5.0
    """padding time so that we don't cross the `retention_time` while the asynchronous messaging takes place"""
    buffer_time::Float64 = 0.5
end


#TODO "convenience constructor for the missing things and finish this docstring"
function SwapperShedder(sim::Simulation, net::RegisterNet, node::Int; kwargs...)
    return SwapperShedder(;sim, net, node, kwargs...)
end

@resumable function (prot::SwapperShedder)()
    rounds = prot.rounds
    round = 1
    while rounds != 0
        qubit_pair = findswapablequbits(prot.net, prot.node, prot.nodeL, prot.nodeH, prot.chooseL, prot.chooseH; sync=true, buffer_time=prot.buffer_time, retention_time=prot.retention_time)
        if isnothing(qubit_pair)
            isnothing(prot.retry_lock_time) && error("We do not yet support waiting on register to make qubits available") # TODO
            @yield timeout(prot.sim, prot.retry_lock_time)
            continue
        end

        (q1, id1, tag1) = qubit_pair[1].slot, qubit_pair[1].id, qubit_pair[1].tag
        (q2, id2, tag2) = qubit_pair[2].slot, qubit_pair[2].id, qubit_pair[2].tag
        @yield lock(q1) & lock(q2) # this should not really need a yield thanks to `findswapablequbits`, but it is better to be defensive
        @yield timeout(prot.sim, prot.local_busy_time)

        untag!(q1, id1)
        # store a history of whom we were entangled to: remote_node_idx, remote_slot_idx, remote_swapnode_idx, remote_swapslot_idx, local_swap_idx
        tag!(q1, EntanglementHistory, tag1[2], tag1[3], tag2[2], tag2[3], q2.idx)

        untag!(q2, id2)
        # store a history of whom we were entangled to: remote_node_idx, remote_slot_idx, remote_swapnode_idx, remote_swapslot_idx, local_swap_idx
        tag!(q2, EntanglementHistory, tag2[2], tag2[3], tag1[2], tag1[3], q1.idx)

        uptotime!((q1, q2), now(prot.sim))
        swapcircuit = LocalEntanglementSwap()
        xmeas, zmeas = swapcircuit(q1, q2)
        # send from here to new entanglement counterpart:
        # tag with EntanglementUpdateX past_local_node, past_local_slot_idx past_remote_slot_idx new_remote_node, new_remote_slot, correction
        msg1 = Tag(EntanglementUpdateX, prot.node, q1.idx, tag1[3], tag2[2], tag2[3], xmeas)
        put!(channel(prot.net, prot.node=>tag1[2]; permit_forward=true), msg1)
        @debug "SwapperShedder @$(prot.node)|round $(round): Send message to $(tag1[2]) | message=`$msg1` | time = $(now(prot.sim))"
        # send from here to new entanglement counterpart:
        # tag with EntanglementUpdateZ past_local_node, past_local_slot_idx past_remote_slot_idx new_remote_node, new_remote_slot, correction
        msg2 = Tag(EntanglementUpdateZ, prot.node, q2.idx, tag2[3], tag1[2], tag1[3], zmeas)
        put!(channel(prot.net, prot.node=>tag2[2]; permit_forward=true), msg2)
        @debug "SwapperShedder @$(prot.node)|round $(round): Send message to $(tag2[2]) | message=`$msg2` | time = $(now(prot.sim))"
        unlock(q1)
        unlock(q2)
        rounds==-1 || (rounds -= 1)
        round += 1
    end
end