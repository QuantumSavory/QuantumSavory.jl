function random_index(arr)
    return rand(keys(arr))
end


function findswapablequbits(net, node, pred_low, pred_high, choose_low, choose_high, chooseslots; agelimit=nothing)
    reg = net[node]
    low_queryresults  = [
        n for n in queryall(reg, EntanglementCounterpart, pred_low, ❓; locked=false, assigned=true)
        if isnothing(agelimit) || !isolderthan(n.slot, agelimit) # TODO add age limit to query and queryall
    ]
    high_queryresults = [
        n for n in queryall(reg, EntanglementCounterpart, pred_high, ❓; locked=false, assigned=true)
        if isnothing(agelimit) || !isolderthan(n.slot, agelimit) # TODO add age limit to query and queryall
    ]

    choosefunc = chooseslots isa Vector{Int} ? in(chooseslots) : chooseslots
    low_queryresults = [qr for qr in low_queryresults if choosefunc(qr.slot.idx)]
    high_queryresults = [qr for qr in high_queryresults if choosefunc(qr.slot.idx)]

    (isempty(low_queryresults) || isempty(high_queryresults)) && return nothing
    il = choose_low((qr.tag[2] for qr in low_queryresults)) # TODO make [2] into a nice named property
    ih = choose_high((qr.tag[2] for qr in high_queryresults))
    return (low_queryresults[il], high_queryresults[ih])
end


"""
$TYPEDEF

A protocol, running at a given node, that finds swappable entangled pairs and performs the swap.

Consider setting an `agelimit` on qubits
and using it together with the cutoff protocol, [`CutoffProt`](@ref),
which deletes qubits that are about to go past their cutoff/retention time.

$TYPEDFIELDS
"""
@kwdef struct SwapperProt <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex of the node where swapping is happening"""
    node::Int
    """function `Int->Bool` or a vector of allowed slot indices, specifying the slots to take among swappable slots in the node"""
    chooseslots::Union{Vector{Int},Function} = alwaystrue
    """the vertex of one of the remote nodes for the swap, arbitrarily referred to as the "low" node (or a predicate function or a wildcard); if you are working on a repeater chain, a good choice is `<(current_node)`, i.e. any node to the "left" of the current node"""
    nodeL::QueryArgs = ❓
    """the vertex of the other remote node for the swap, the "high" counterpart of `nodeL`; if you are working on a repeater chain, a good choice is `>(current_node)`, i.e. any node to the "right" of the current node"""
    nodeH::QueryArgs = ❓
    """the `nodeL` predicate can return many positive candidates; `chooseL` picks one of them (by index into the array of filtered `nodeL` results), defaults to a random pick `arr->rand(keys(arr))`; if you are working on a repeater chain a good choice is `argmin`, i.e. the node furthest to the "left" """
    chooseL::Function = random_index
    """the `nodeH` counterpart for `chooseH`; if you are working on a repeater chain a good choice is `argmax`, i.e. the node furthest to the "right" """
    chooseH::Function = random_index
    """fixed "busy time" duration immediately before starting entanglement generation attempts"""
    local_busy_time::Float64 = 0.0 # TODO the gates should have that busy time built in
    """how long to wait before retrying to lock qubits if no qubits are available (`nothing` for queuing up and waiting)"""
    retry_lock_time::Union{Float64,Nothing} = 0.1
    """how many rounds of this protocol to run (`-1` for infinite))"""
    rounds::Int = -1
    """what is the oldest a qubit should be to be picked for a swap (to avoid swapping with qubits that are about to be deleted, the agelimit should be shorter than the retention time of the cutoff protocol) (`nothing` for no limit) -- you probably want to use [`CutoffProt`](@ref) if you have an agelimit"""
    agelimit::Union{Float64,Nothing} = nothing
end

#TODO "convenience constructor for the missing things and finish this docstring"
function SwapperProt(sim::Simulation, net::RegisterNet, node::Int; kwargs...)
    return SwapperProt(;sim, net, node, kwargs...)
end

SwapperProt(net::RegisterNet, node::Int; kwargs...) = SwapperProt(get_time_tracker(net), net, node; kwargs...)

@resumable function (prot::SwapperProt)()
    rounds = prot.rounds
    round = 1
    while rounds != 0
        qubit_pair_ = findswapablequbits(prot.net, prot.node, prot.nodeL, prot.nodeH, prot.chooseL, prot.chooseH, prot.chooseslots; agelimit=prot.agelimit)
        if isnothing(qubit_pair_)
            if isnothing(prot.retry_lock_time)
                @debug "SwapperProt: no swappable qubits found. Waiting for tag change..."
                @yield onchange(prot.net[prot.node], Tag)
            else
                @debug "SwapperProt: no swappable qubits found. Waiting a fixed amount of time..."
                @yield timeout(prot.sim, prot.retry_lock_time::Float64)
            end
            continue
        end
        # The compiler is not smart enough to figure out that qubit_pair_ is not nothing, so we need to tell it explicitly. A new variable name is needed due to @resumable.
        qubit_pair = qubit_pair_::NTuple{2, QueryOnRegResult}

        (q1, id1, tag1) = qubit_pair[1].slot, qubit_pair[1].id, qubit_pair[1].tag
        (q2, id2, tag2) = qubit_pair[2].slot, qubit_pair[2].id, qubit_pair[2].tag

        @yield lock(q1) & lock(q2) # this should not really need a yield thanks to `findswapablequbits` which queries only for unlocked qubits, but it is better to be defensive
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
        msg1 = Tag(EntanglementUpdateX, prot.node, q1.idx, tag1[3], tag2[2], tag2[3], Int(xmeas))
        put!(channel(prot.net, prot.node=>tag1[2]; permit_forward=true), msg1)
        @debug "SwapperProt @$(prot.node)|round $(round): Send message to $(tag1[2]) | message=`$msg1` | time = $(now(prot.sim))"
        # send from here to new entanglement counterpart:
        # tag with EntanglementUpdateZ past_local_node, past_local_slot_idx past_remote_slot_idx new_remote_node, new_remote_slot, correction
        msg2 = Tag(EntanglementUpdateZ, prot.node, q2.idx, tag2[3], tag1[2], tag1[3], Int(zmeas))
        put!(channel(prot.net, prot.node=>tag2[2]; permit_forward=true), msg2)
        @debug "SwapperProt @$(prot.node)|round $(round): Send message to $(tag2[2]) | message=`$msg2` | time = $(now(prot.sim))"
        @yield timeout(prot.sim, prot.local_busy_time)
        unlock(q1)
        unlock(q2)
        rounds==-1 || (rounds -= 1)
        round += 1
    end
end
