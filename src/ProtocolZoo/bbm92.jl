"""
$TYPEDEF

A protocol implementing the BBM92 entanglement-based quantum key distribution (QKD)
protocol between two nodes [bennett1992quantum](@cite).

Both parties (Alice at `nodeA` and Bob at `nodeB`) share Bell pairs distributed by
the lower-layer entanglement protocols ([`EntanglerProt`](@ref), [`SwapperProt`](@ref),
[`EntanglementTracker`](@ref)). For each delivered pair, each party independently
chooses a random measurement basis (Z or X) and performs a projective measurement.
In a subsequent classical sifting step (handled implicitly by the coordinator),
only the events where both chose the same basis are kept as raw key bits.
A subset of these sifted bits can be used to estimate the quantum bit error rate (QBER).

The measurement log is stored in `_log` and can be post-processed with
[`sifted_key`](@ref), [`qber_estimate`](@ref), and [`keyrate`](@ref).

This protocol permits virtual edges, meaning it can operate between any two nodes
in the network regardless of whether they are physically connected by an edge.

$FIELDS
"""
@kwdef struct BBM92Prot <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex index of node A (Alice)"""
    nodeA::Int
    """the vertex index of node B (Bob)"""
    nodeB::Int
    """time period between successive queries on the nodes (`nothing` for queuing up and waiting for available pairs)"""
    period::Union{Float64,Nothing} = 0.1
    """tag type to query for; defaults to `EntanglementCounterpart`"""
    tag::Any = EntanglementCounterpart
    """stores the raw measurement log entries"""
    _log::Vector{@NamedTuple{t::Float64, basisA::Int, basisB::Int, outcomeA::Int, outcomeB::Int}} = @NamedTuple{t::Float64, basisA::Int, basisB::Int, outcomeA::Int, outcomeB::Int}[]
end

function BBM92Prot(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...)
    return BBM92Prot(;sim, net, nodeA, nodeB, kwargs...)
end
function BBM92Prot(net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...)
    return BBM92Prot(get_time_tracker(net), net, nodeA, nodeB; kwargs...)
end

permits_virtual_edge(::BBM92Prot) = true

@resumable function (prot::BBM92Prot)()
    regA = prot.net[prot.nodeA]
    regB = prot.net[prot.nodeB]
    bases = (Z, X)

    while true
        # Query node A for a qubit entangled with node B
        query1 = query(regA, prot.tag, prot.nodeB, ❓; locked=false, assigned=true)
        if isnothing(query1)
            if isnothing(prot.period)
                @debug "$(timestr(prot.sim)) BBM92Prot($(compactstr(regA)), $(compactstr(regB))): no pair at Alice, waiting on tag change"
                @yield onchange(regA, Tag)
            else
                @debug "$(timestr(prot.sim)) BBM92Prot($(compactstr(regA)), $(compactstr(regB))): no pair at Alice, waiting fixed time"
                @yield timeout(prot.sim, prot.period::Float64)
            end
            continue
        end

        # Query node B for the reciprocal entanglement tag
        query2 = query(regB, prot.tag, prot.nodeA, query1.slot.idx; locked=false, assigned=true)
        if isnothing(query2)
            if isnothing(prot.period)
                @debug "$(timestr(prot.sim)) BBM92Prot($(compactstr(regA)), $(compactstr(regB))): pair at Alice but not yet at Bob, waiting on tag change"
                @yield onchange(regB, Tag)
            else
                @debug "$(timestr(prot.sim)) BBM92Prot($(compactstr(regA)), $(compactstr(regB))): pair at Alice but not yet at Bob, waiting fixed time"
                @yield timeout(prot.sim, prot.period::Float64)
            end
            continue
        end

        q1 = query1.slot
        q2 = query2.slot
        @yield lock(q1) & lock(q2)

        @debug "$(timestr(prot.sim)) BBM92Prot($(compactstr(regA)), $(compactstr(regB))): measuring pair .$(q1.idx) and .$(q2.idx)"

        untag!(q1, query1.id)
        untag!(q2, query2.id)

        # Each party independently chooses a random measurement basis: 1=Z, 2=X
        basisA_idx = rand(1:2)::Int
        basisB_idx = rand(1:2)::Int

        # Perform projective measurements (each project_traceout! destroys the measured qubit)
        outcomeA = project_traceout!(q1, bases[basisA_idx]; time=now(prot.sim))::Int
        outcomeB = project_traceout!(q2, bases[basisB_idx]; time=now(prot.sim))::Int

        push!(prot._log, (t=now(prot.sim), basisA=basisA_idx, basisB=basisB_idx, outcomeA=outcomeA, outcomeB=outcomeB))

        unlock(q1)
        unlock(q2)

        if !isnothing(prot.period)
            @yield timeout(prot.sim, prot.period)
        end
    end
end


"""
    sifted_key(log)

Extract the sifted key from a BBM92 measurement log.

Returns `(keyA, keyB)` where each is a `Vector{Int}` of key bits (0 or 1).
Only measurements where both parties chose the same basis are included.
For a noiseless channel, `keyA == keyB`.
"""
function sifted_key(log)
    keyA = Int[]
    keyB = Int[]
    for e in log
        if e.basisA == e.basisB
            push!(keyA, e.outcomeA - 1)
            push!(keyB, e.outcomeB - 1)
        end
    end
    return keyA, keyB
end

"""
    qber_estimate(log)

Estimate the quantum bit error rate (QBER) from a BBM92 measurement log.

QBER is the fraction of sifted key bits where Alice and Bob disagree.
Returns `NaN` if no sifted bits are available.
"""
function qber_estimate(log)
    keyA, keyB = sifted_key(log)
    n = length(keyA)
    n == 0 && return NaN
    errors = count(a != b for (a, b) in zip(keyA, keyB))
    return errors / n
end

"""
    keyrate(log)

Compute the average sifted key generation rate (sifted bits per unit time)
from a BBM92 measurement log.
"""
function keyrate(log)
    isempty(log) && return 0.0
    nsifted = count(e -> e.basisA == e.basisB, log)
    return nsifted / log[end].t
end
