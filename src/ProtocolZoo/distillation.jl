# pick slots in reg without the given distillation tag (defaults to DistilledTag)
function nondistilled(reg::Register, tag::DataType=DistilledTag)
    return (slot) -> isnothing(query(reg[slot], tag))
end

"""
Pick two distinct random elements from a vector of candidate Bell pairs.

This is the default `choose_pairs` strategy for [`BBPSSWProt`](@ref): given
the list of Bell pairs available for distillation, return a tuple
`(distilled, sacrificed)` of two distinct pairs chosen uniformly at random.
The caller is responsible for ensuring `length(pairs) >= 2`.
"""
function random_pair(pairs)
    n = length(pairs)
    i = rand(1:n)
    j = rand(1:(n - 1))
    j >= i && (j += 1)
    return (pairs[i], pairs[j])
end

"""
$TYPEDEF

This tag is used to mark a register slot when the stored qubit
has successfully undergone distillation.

$TYPEDFIELDS

For example, see also: [`BBPSSWProt`](@ref)
"""
@kwdef struct DistilledTag end

"""
$TYPEDEF

Classical message exchanged between the two parties of [`BBPSSWProt`](@ref)
carrying the outcome of one distillation round. It is used as a `Tag` token
(`Tag(BBPSSWMessage, sender_node, success_bit)`) so that neither side commits
the per-pair bookkeeping before the classical-channel delay between the nodes
has elapsed.
"""
struct BBPSSWMessage end

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
@kwdef struct BBPSSWProt <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
     """a network graph of registers"""
    net::RegisterNet
    """the vertex index of node A"""
    nodeA::Int
    """the vertex index of node B"""
    nodeB::Int
    """Tag to be added to the entangled qubits, or `nothing` to skip tagging. The tag should not have any field. Defaults to `DistilledTag`."""
    tag::Union{DataType, Nothing} = DistilledTag
    """how many rounds of this protocol to run (`-1` for infinite)"""
    rounds::Int = -1
    """function `Int->Bool` or a vector of allowed slot indices, specifying the slots to take among distillable slots in the node"""
    chooseslotsA::Union{Vector{Int}, Function}
    """function `Int->Bool` or a vector of allowed slot indices, specifying the slots to take among distillable slots in the node"""
    chooseslotsB::Union{Vector{Int}, Function}
    """policy for selecting which two Bell pairs to consume in each distillation round. Receives a `Vector` of valid candidate pairs (each a `Tuple{QueryOnRegResult, QueryOnRegResult}` for the slot at `nodeA` and at `nodeB`) and returns a tuple `(distilled, sacrificed)` of two distinct pairs from that vector. Defaults to `random_pair`; override to implement strategies like oldest/youngest, highest fidelity, etc."""
    choose_pairs::Function = random_pair
    """what is the oldest a qubit should be to be picked for distillation (to avoid distilling qubits that are about to be deleted, the agelimit should be shorter than the retention time of the cutoff protocol) (`nothing` for no limit) -- you probably want to use [`CutoffProt`](@ref) if you have an agelimit"""
    agelimit::Union{Nothing, Float64} = nothing
    """how long to wait before retrying to lock qubits if no qubits are available (`nothing` for queuing up and waiting)"""
    retry_lock_time::Union{Nothing, Float64} = nothing
    """fixed "busy time" duration immediately before starting the next distillation round"""
    local_busy_time::Union{Float64, Nothing} = nothing
end

"""
Convenience constructor for `BBPSSWProt`.
Defaults for missing `chooseslotsA` and `chooseslotsB` are set to filter for slots that have no distillation tag (`DistilledTag` by default).
Defaults for remaining missing fields are described in the [`BBPSSWProt`](@ref) docstring.
- `sim::Simulation`: time-and-schedule-tracking instance from `ConcurrentSim`
- `net::RegisterNet`: a network graph of registers
- `nodeA::Int`: the vertex index of node A
- `nodeB::Int`: the vertex index of node B
- `kwargs...`: optional keyword arguments for `BBPSSWProt` remaining fields
"""
function BBPSSWProt(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...)
    tag = get(kwargs, :tag, DistilledTag)
    chooseslotsA = isnothing(tag) ? alwaystrue : nondistilled(net[nodeA], tag::DataType)
    chooseslotsB = isnothing(tag) ? alwaystrue : nondistilled(net[nodeB], tag::DataType)
    return BBPSSWProt(; sim, net, nodeA, nodeB, chooseslotsA, chooseslotsB, kwargs...)
end

"""
Convenience constructor for `BBPSSWProt`.
Defaults for missing `sim` is taken from the network's time tracker.
Defaults for missing `chooseslotsA` and `chooseslotsB` are set to filter for slots that have no distillation tag (`DistilledTag` by default).
Defaults for remaining missing fields are described in the [`BBPSSWProt`](@ref) docstring.
- `net::RegisterNet`: a network graph of registers
- `nodeA::Int`: the vertex index of node A
- `nodeB::Int`: the vertex index of node B
- `kwargs...`: optional keyword arguments for `BBPSSWProt` remaining fields
"""
BBPSSWProt(net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...) = BBPSSWProt(get_time_tracker(net), net, nodeA, nodeB; kwargs...)

@resumable function(prot::BBPSSWProt)()
    mbB = messagebuffer(prot.net, prot.nodeB)

    rounds = prot.rounds
    round = 1
    while rounds != 0
        two_qubit_pairs_ = finddistillablequbits(prot.net, prot.nodeA, prot.nodeB, prot.chooseslotsA, prot.chooseslotsB, prot.choose_pairs; agelimit=prot.agelimit)
        if isnothing(two_qubit_pairs_)
            if isnothing(prot.retry_lock_time)
                @debug "BBPSSWProt: no distillable qubits found. Waiting for tag change..."
                @yield (onchange(prot.net[prot.nodeA], Tag) | onchange(prot.net[prot.nodeB], Tag))
            else
                @debug "BBPSSWProt: no distillable qubits found. Waiting a fixed amount of time..."
                @yield timeout(prot.sim, prot.retry_lock_time::Float64)
            end
            continue
        end
        # The compiler is not smart enough to figure out that two_qubit_pairs_ is not nothing, so we need to tell it explicitly. A new variable name is needed due to @resumable.
        two_qubit_pairs = two_qubit_pairs_::Tuple{NTuple{2, QueryOnRegResult}, NTuple{2, QueryOnRegResult}}
        distilled_pair = two_qubit_pairs[1]
        sacrificed_pair = two_qubit_pairs[2]

        q1 = distilled_pair[1].slot
        q2 = distilled_pair[2].slot
        q3 = sacrificed_pair[1].slot
        q4 = sacrificed_pair[2].slot

        @yield lock(q1) & lock(q2) & lock(q3) & lock(q4)  # this should not really need a yield thanks to `finddistillablequbits` which queries only for unlocked qubits, but it is better to be defensive

        # Across the lock yield, another process could have consumed the
        # tagged entanglement; re-query under the locks to confirm the
        # reciprocal tags are still present and to capture fresh ids that
        # are safe to pass to `untag!` later in the round.
        fresh1 = query(q1, distilled_pair[1].tag;  assigned=true)
        fresh2 = query(q2, distilled_pair[2].tag;  assigned=true)
        fresh3 = query(q3, sacrificed_pair[1].tag; assigned=true)
        fresh4 = query(q4, sacrificed_pair[2].tag; assigned=true)
        if isnothing(fresh1) || isnothing(fresh2) || isnothing(fresh3) || isnothing(fresh4)
            unlock(q1); unlock(q2); unlock(q3); unlock(q4)
            continue
        end
        id1 = (fresh1::QueryOnRegResult).id
        id2 = (fresh2::QueryOnRegResult).id
        id3 = (fresh3::QueryOnRegResult).id
        id4 = (fresh4::QueryOnRegResult).id

        uptotime!((q1, q2, q3, q4), now(prot.sim))


        purify_circuit = Purify2to1()
        success = purify_circuit(q1, q2, q3, q4)
        # let's untag the sacrificed qubits
        untag!(q3, id3)
        untag!(q4, id4)

        # Communicate the outcome from nodeA to nodeB over the classical
        # channel; the per-pair bookkeeping below only commits once nodeB
        # has received the message, which captures the channel delay.
        outcome_msg = Tag(BBPSSWMessage, prot.nodeA, success ? 1 : 0)
        put!(channel(prot.net, prot.nodeA => prot.nodeB; permit_forward=true), outcome_msg)
        @debug "BBPSSWProt @$(prot.nodeA)→$(prot.nodeB) round $(round): outcome=$(success) sent at $(now(prot.sim))"
        @yield querydelete_wait!(mbB, BBPSSWMessage, prot.nodeA, ❓)

        if success
            # Mark distilled qubits with the configured tag (if any)
            if !isnothing(prot.tag)
                tag!(q1, prot.tag::DataType)
                tag!(q2, prot.tag::DataType)
            end
            # TODO: apply a bilateral twirl to (q1, q2) here so the surviving
            # pair is symmetrized into Werner form, as specified in the
            # original BBPSSW protocol (Bennett et al. 1996). Today we cannot
            # express the full single-qubit Clifford group via `apply!` — it
            # requires a symbolic phase/`S` gate that QuantumSymbolics does
            # not yet export. Wire this up once QuantumSymbolics PR #95
            # (rotation gates) lands.
            @debug "BBPSSWProt nodes $(prot.nodeA) and $(prot.nodeB). Round $(round): Distillation succeeded on qubits $(prot.nodeA).$(q1.idx) and $(prot.nodeB).$(q2.idx) (sacrificed $(prot.nodeA).$(q3.idx) and $(prot.nodeB).$(q4.idx))."
        else
            # untag distilled qubits if distillation failed
            untag!(q1, id1)
            untag!(q2, id2)
            @debug "BBPSSWProt nodes $(prot.nodeA) and $(prot.nodeB). Round $(round): Distillation failed on qubits $(prot.nodeA).$(q1.idx) and $(prot.nodeB).$(q2.idx) (sacrificed $(prot.nodeA).$(q3.idx) and $(prot.nodeB).$(q4.idx)). Released."
        end

        if !isnothing(prot.local_busy_time)
            @yield timeout(prot.sim, prot.local_busy_time::Float64)
        end
        unlock(q1)
        unlock(q2)
        unlock(q3)
        unlock(q4)

        rounds==-1 || (rounds -= 1)
        round += 1
    end

    
end

function finddistillablequbits(net, nodeA, nodeB, chooseslotsA, chooseslotsB, choose_pairs; agelimit=nothing)
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

    # Build the list of valid Bell pairs (low_qr, high_qr) where the two slots
    # are reciprocally entangled with each other; checking both directions
    # avoids pairing on stale/half-updated tags (e.g. after a swap whose
    # update has only reached one side).
    pairs = NTuple{2, QueryOnRegResult}[]
    for low_qr in low_queryresults
        for high_qr in high_queryresults
            if low_qr.slot.idx == high_qr.tag[3] && high_qr.slot.idx == low_qr.tag[3]
                push!(pairs, (low_qr, high_qr))
                break
            end
        end
    end

    length(pairs) < 2 && return nothing
    return choose_pairs(pairs)::NTuple{2, NTuple{2, QueryOnRegResult}}
end