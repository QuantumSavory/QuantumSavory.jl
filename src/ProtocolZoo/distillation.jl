# pick slots in reg without a DistilledTag
function nondistilled(reg::Register)
    return (slot) -> begin
        regref = reg[slot]
        dist = query(regref, DistilledTag)
        return isnothing(dist)
    end
end

"""
$TYPEDEF

This tag is used to mark a register slot when the stored qubit
has successfully undergone distillation.

$TYPEDFIELDS

For example, see also: [`BBPPSWProt`](@ref)
"""
@kwdef struct DistilledTag end

"""
$TYPEDEF

A protocol implementing the BBPSSW [Bennett et al. 1996]
entanglement distillation protocol. It purifies 2 Bell
pairs into 1 pair. It traces out the
sacrificed qubits (always) and the distilled qubits
(if distillation fails). Whenever two pairs of eligible slots
are available, the protocol locks them and starts distillation.
Slots are eligible if they are entangled with each other,
not locked, and pass the specified filters.

$TYPEDFIELDS

See also: [`Purify2to1`](@ref)
"""
@kwdef struct BBPPSWProt <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
     """a network graph of registers"""
    net::RegisterNet
    """the vertex index of node A"""
    nodeA::Int
    """the vertex index of node B"""
    nodeB::Int
    """Tag to be added to the entangled qubits or nothing to not add any tag. The tag should not have any field. Defaults to `DistilledTag`."""
    tag::DataType = DistilledTag
    """how many rounds of this protocol to run (`-1` for infinite)"""
    rounds::Int = -1
    """function `Int->Bool` or a vector of allowed slot indices, specifying the slots to take among distillable slots in the node"""
    chooseslotsA::Union{Vector{Int}, Function}
    """function `Int->Bool` or a vector of allowed slot indices, specifying the slots to take among distillable slots in the node"""
    chooseslotsB::Union{Vector{Int}, Function}
    """what is the oldest a qubit should be to be picked for distillation (to avoid distilling qubits that are about to be deleted, the agelimit should be shorter than the retention time of the cutoff protocol) (`nothing` for no limit) -- you probably want to use [`CutoffProt`](@ref) if you have an agelimit"""
    agelimit::Union{Nothing, Float64} = nothing
    """how long to wait before retrying to lock qubits if no qubits are available (`nothing` for queuing up and waiting)"""
    retry_lock_time::Union{Nothing, Float64} = nothing
    """fixed "busy time" duration immediately before starting the next distillation round"""
    local_busy_time::Union{Float64, Nothing} = nothing
end

"""
Convenience constructor for `BBPPSWProt`.
Defaults for missing fields are described in the [`BBPPSWProt`](@ref) docstring.
- `sim::Simulation`: time-and-schedule-tracking instance from `ConcurrentSim`
- `net::RegisterNet`: a network graph of registers
- `nodeA::Int`: the vertex index of node A
- `nodeB::Int`: the vertex index of node B
- `chooseslotsA::Union{Vector{Int}, Function}`: function `Int->Bool` or a vector of allowed slot indices, specifying the slots to take among distillable slots in the node
- `chooseslotsB::Union{Vector{Int}, Function}`: function `Int->Bool` or a vector of allowed slot indices, specifying the slots to take among distillable slots in the node
- `kwargs...`: optional keyword arguments for `BBPPSWProt` remaining fields
"""
function BBPPSWProt(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int, chooseslotsA::Union{Vector{Int}, Function}, chooseslotsB::Union{Vector{Int}, Function}; kwargs...)
    return BBPPSWProt(sim, net, nodeA, nodeB; chooseslotsA=chooseslotsA, chooseslotsB=chooseslotsB, kwargs...)
end

"""
Convenience constructor for `BBPPSWProt`. 
Defaults for missing `chooseslotsA` and `chooseslotsB` are set to filter for slots that have no distillation tag (`DistilledTag` by default).
Defaults for remaining missing fields are described in the [`BBPPSWProt`](@ref) docstring.
- `sim::Simulation`: time-and-schedule-tracking instance from `ConcurrentSim`
- `net::RegisterNet`: a network graph of registers
- `nodeA::Int`: the vertex index of node A
- `nodeB::Int`: the vertex index of node B
- `kwargs...`: optional keyword arguments for `BBPPSWProt` remaining fields
"""
function BBPPSWProt(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...)
    return BBPPSWProt(;sim, net, nodeA, nodeB, chooseslotsA=nondistilled(net[nodeA]), chooseslotsB=nondistilled(net[nodeB]), kwargs...)
end

"""
Convenience constructor for `BBPPSWProt`.
Defaults for missing `sim` is taken from the network's time tracker.
Defaults for missing `chooseslotsA` and `chooseslotsB` are set to filter for slots that have no distillation tag (`DistilledTag` by default).
Defaults for remaining missing fields are described in the [`BBPPSWProt`](@ref) docstring.
- `net::RegisterNet`: a network graph of registers
- `nodeA::Int`: the vertex index of node A
- `nodeB::Int`: the vertex index of node B
- `kwargs...`: optional keyword arguments for `BBPPSWProt` remaining fields
"""
BBPPSWProt(net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...) = BBPPSWProt(get_time_tracker(net), net, nodeA=nodeA, nodeB=nodeB; kwargs...)

@resumable function(prot::BBPPSWProt)()
    regA = prot.net[prot.nodeA]
    regB = prot.net[prot.nodeB]

    rounds = prot.rounds
    round = 1
    while rounds != 0
        two_qubit_pairs_ = finddistillablequbits(prot.net, prot.nodeA, prot.nodeB, prot.chooseslotsA, prot.chooseslotsB; agelimit=prot.agelimit)
        if isnothing(two_qubit_pairs_)
            if isnothing(prot.retry_lock_time)
                @debug "BBPPSWProt: no distillable qubits found. Waiting for tag change..."
                @yield (onchange(prot.net[prot.nodeA], Tag) | onchange(prot.net[prot.nodeB], Tag))
            else
                @debug "BBPPSWProt: no distillable qubits found. Waiting a fixed amount of time..."
                @yield timeout(prot.sim, prot.retry_lock_time::Float64)
            end
            continue
        end
        # The compiler is not smart enough to figure out that qubit_pair_ is not nothing, so we need to tell it explicitly. A new variable name is needed due to @resumable.
        distilled_pair = two_qubit_pairs_[1]::NTuple{2, Base.NamedTuple{(:slot, :id, :tag), Base.Tuple{RegRef, Int128, Tag}}} # TODO: replace by `NTuple{2, @NamedTuple{slot::RegRef, id::Int128, tag::Tag}}` once https://github.com/JuliaDynamics/ResumableFunctions.jl/issues/104 is resolved
        sacrificed_pair = two_qubit_pairs_[2]::NTuple{2, Base.NamedTuple{(:slot, :id, :tag), Base.Tuple{RegRef, Int128, Tag}}} # TODO: replace by `NTuple{2, @NamedTuple{slot::RegRef, id::Int128, tag::Tag}}` once

        (q1, id1, tag1) = distilled_pair[1].slot, distilled_pair[1].id, distilled_pair[1].tag
        (q2, id2, tag2) = distilled_pair[2].slot, distilled_pair[2].id, distilled_pair[2].tag

        (q3, id3, tag3) = sacrificed_pair[1].slot, sacrificed_pair[1].id, sacrificed_pair[1].tag
        (q4, id4, tag4) = sacrificed_pair[2].slot, sacrificed_pair[2].id, sacrificed_pair[2].tag

        @yield lock(q1) & lock(q2) & lock(q3) & lock(q4)  # this should not really need a yield thanks to `finddistillablequbits` which queries only for unlocked qubits, but it is better to be defensive

        uptotime!((q1, q2, q3, q4), now(prot.sim))


        purify_circuit = Purify2to1()
        success = purify_circuit(q1, q2, q3, q4)
        # let's untag the sacrificed qubits
        untag!(q3, id3)
        untag!(q4, id4)

        if success
            # Mark distilled qubits with DistilledTag
            tag!(q1, prot.tag)
            tag!(q2, prot.tag)
            @debug "BBPPSWProt nodes $(prot.nodeA) and $(prot.nodeB). Round $(round): Distillation succeeded on qubits $(prot.nodeA).$(q1.idx) and $(prot.nodeB).$(q2.idx) (sacrificed $(prot.nodeA).$(q3.idx) and $(prot.nodeB).$(q4.idx))."
        else
            # untag distilled qubits if distillation failed
            untag!(q1, id1)
            untag!(q2, id2)
            @debug "BBPPSWProt nodes $(prot.nodeA) and $(prot.nodeB). Round $(round): Distillation failed on qubits $(prot.nodeA).$(q1.idx) and $(prot.nodeB).$(q2.idx) (sacrificed $(prot.nodeA).$(q3.idx) and $(prot.nodeB).$(q4.idx)). Released."
        end
        
        # TODO: emulate classical communication time here?

        !isnothing(prot.local_busy_time) && @yield timeout(prot.sim, prot.local_busy_time)
        unlock(q1)
        unlock(q2)
        unlock(q3)
        unlock(q4)

        rounds==-1 || (rounds -= 1)
        round += 1
    end

    
end

function finddistillablequbits(net, nodeA, nodeB, chooseslotsA, chooseslotsB; agelimit=nothing)
    regA = net[nodeA]
    regB = net[nodeB]
    low_queryresults  = [
        n for n in queryall(regA, EntanglementCounterpart, nodeB, ❓; locked=false, assigned=true)
        if isnothing(agelimit) || !isolderthan(n.slot, agelimit) # TODO add age limit to query and queryall
    ]
    high_queryresults = [
        n for n in queryall(regB, EntanglementCounterpart, nodeA, ❓; locked=false, assigned=true)
        if isnothing(agelimit) || !isolderthan(n.slot, agelimit) # TODO add age limit to query and queryall
    ]

    choosefuncA = chooseslotsA isa Vector{Int} ? in(chooseslotsA) : chooseslotsA
    choosefuncB = chooseslotsB isa Vector{Int} ? in(chooseslotsB) : chooseslotsB
    low_queryresults = [qr for qr in low_queryresults if choosefuncA(qr.slot.idx)]
    high_queryresults = [qr for qr in high_queryresults if choosefuncB(qr.slot.idx)]
    
    (isempty(low_queryresults) || isempty(high_queryresults)) && return nothing
    @debug "Found $(length(low_queryresults)) candidate qubits in node $nodeA and $(length(high_queryresults)) candidate qubits in node $nodeB for distillation."
    distilled = nothing
    sacrificed = nothing
    res = nothing
    # iterate through low_queryresults list and find two matching pairs (4 qubits total). TODO: make this search customizable, e.g., oldest/youngest qubits, highest fidelity, random, ...
    for il in eachindex(low_queryresults)
        for ih in eachindex(high_queryresults)
            if low_queryresults[il].slot.idx == high_queryresults[ih].tag[3]
                sacrificed = !isnothing(distilled) ? (low_queryresults[il], high_queryresults[ih]) : sacrificed
                distilled = isnothing(distilled) ? (low_queryresults[il], high_queryresults[ih]) : distilled
                break
            end
        end
        !isnothing(sacrificed) && break
    end

    return isnothing(distilled) || isnothing(sacrificed) ? nothing : (distilled, sacrificed)
end