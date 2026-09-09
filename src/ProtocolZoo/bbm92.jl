"""
$TYPEDEF

Entanglement-based quantum key distribution following Bennett, Brassard and Mermin 1992.

Each round consumes one entangled pair shared between `nodeA` and `nodeB`, measures each
half in a basis drawn independently and uniformly from `Z` and `X`, and records the two
bases and the two outcomes. Rounds in which the two bases agree form the sifted key; the
rest are discarded. [`sifted_key`](@ref) and [`qber`](@ref) read the recorded rounds.

The pairs themselves are not produced here. Run an [`EntanglerProt`](@ref) (and a swapper,
if the two nodes are not neighbours) so that reciprocal `EntanglementCounterpart` tags are
present, exactly as [`EntanglementConsumer`](@ref) expects.

Set `eavesdrop=true` to run an intercept-resend attacker on the `nodeB` arm: before the
legitimate measurement the attacker measures in a basis of their own and re-prepares the
half in the eigenstate they found. Their basis matches the legitimate one half of the time
and randomises the outcome otherwise, so the sifted key picks up a quarter of errors. This
is the textbook attack only, not a general security model. The attack is applied to the stored
half as the pair is consumed rather than while it is in flight, which gives the same statistics
here because nothing else acts on the pair in between.

$FIELDS
"""
@kwdef struct BBM92Prot <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex index of node A"""
    nodeA::Int
    """the vertex index of node B"""
    nodeB::Int
    """number of rounds to run, or `-1` to run until the simulation ends"""
    rounds::Int = -1
    """time period between successive queries for a shared pair (`nothing` to wait on a tag change instead)"""
    period::Union{Float64,Nothing} = 0.1
    """whether an intercept-resend attacker acts on the `nodeB` half before it is measured"""
    eavesdrop::Bool = false
    """recorded rounds; the storage type is not part of the public API and may change in future versions"""
    _log::Vector{@NamedTuple{t::Float64, basisA::Symbol, basisB::Symbol, outcomeA::Int, outcomeB::Int, basisE::Symbol}} = @NamedTuple{t::Float64, basisA::Symbol, basisB::Symbol, outcomeA::Int, outcomeB::Int, basisE::Symbol}[]

    function BBM92Prot(sim, net, nodeA, nodeB, rounds, period, eavesdrop, _log)
        @domain isnothing(period) || period > 0
        return new(sim, net, nodeA, nodeB, rounds, period, eavesdrop, _log)
    end
end

function BBM92Prot(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...)
    return BBM92Prot(; sim, net, nodeA, nodeB, kwargs...)
end
function BBM92Prot(net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...)
    return BBM92Prot(get_time_tracker(net), net, nodeA, nodeB; kwargs...)
end

permits_virtual_edge(::Type{BBM92Prot}) = true

protocol_catalog_metadata(::Type{BBM92Prot}) = (
    attachment = :edge,
    attachment_fields = (node_a=:nodeA, node_b=:nodeB),
    required_fields = (),
)

_bbm92_observable(basis::Symbol) = basis === :Z ? Z : X
_bbm92_eigenstate(basis::Symbol, outcome::Int) =
    basis === :Z ? (outcome == 1 ? Z1 : Z2) : (outcome == 1 ? X1 : X2)

@resumable function (prot::BBM92Prot)()
    regA = prot.net[prot.nodeA]
    regB = prot.net[prot.nodeB]
    remaining = prot.rounds
    while remaining != 0
        query1 = query(regA, EntanglementCounterpart, prot.nodeB, ❓, ❓; locked=false, assigned=true)
        if isnothing(query1)
            @debug(
                "Entanglement unavailable",
                _group=LOG_GROUPS.protocol,
                event=:entanglement_unavailable,
                protocol_log_context(prot)...,
                src_node=prot.nodeA,
                wait_mode=isnothing(prot.period) ? :tag_change : :fixed_delay,
                retry_after_s=prot.period,
            )
            if isnothing(prot.period)
                @yield onchange(regA, Tag)
            else
                @yield timeout(prot.sim, prot.period::Float64)
            end
            continue
        end
        pair_id = query1.tag[4]
        query2 = query(regB, EntanglementCounterpart, prot.nodeA, query1.slot.idx, pair_id; locked=false, assigned=true)
        if isnothing(query2)
            @debug(
                "Entanglement unavailable",
                _group=LOG_GROUPS.protocol,
                event=:entanglement_unavailable,
                protocol_log_context(prot)...,
                dst_node=prot.nodeB,
                wait_mode=isnothing(prot.period) ? :tag_change : :fixed_delay,
                retry_after_s=prot.period,
            )
            if isnothing(prot.period)
                @yield onchange(regB, Tag)
            else
                @yield timeout(prot.sim, prot.period::Float64)
            end
            continue
        end

        q1 = query1.slot
        q2 = query2.slot
        @yield lock(q1) & lock(q2)
        query1 = query(q1, EntanglementCounterpart, prot.nodeB, q2.idx, pair_id; locked=true, assigned=true)
        query2 = query(q2, EntanglementCounterpart, prot.nodeA, q1.idx, pair_id; locked=true, assigned=true)
        if isnothing(query1) || isnothing(query2)
            @debug(
                "Entanglement query was invalidated",
                _group=LOG_GROUPS.protocol,
                event=:query_invalidated,
                protocol_log_context(prot)...,
                slots=(q1.idx, q2.idx),
                pair_id=pair_id,
            )
            unlock(q1)
            unlock(q2)
            continue
        end
        untag!(q1, query1.id)
        untag!(q2, query2.id)

        basisE = :none
        if prot.eavesdrop
            basisE = rand((:Z, :X))
            outcomeE = project_traceout!(q2, _bbm92_observable(basisE))
            initialize!(q2, _bbm92_eigenstate(basisE, outcomeE))
        end

        basisA = rand((:Z, :X))
        basisB = rand((:Z, :X))
        outcomeA = project_traceout!(q1, _bbm92_observable(basisA))
        outcomeB = project_traceout!(q2, _bbm92_observable(basisB))
        push!(prot._log, (; t=now(prot.sim), basisA, basisB, outcomeA, outcomeB, basisE))
        @debug(
            "Measured a BBM92 round",
            _group=LOG_GROUPS.protocol,
            event=:bbm92_round,
            protocol_log_context(prot)...,
            slots=(q1.idx, q2.idx),
            pair_id=pair_id,
            bases=(basisA, basisB),
            sifted=basisA === basisB,
        )

        unlock(q1)
        unlock(q2)
        remaining -= 1
    end
end

"""
$TYPEDSIGNATURES

The sifted key of a [`BBM92Prot`](@ref) run, as node A's outcomes over the rounds in which
both nodes happened to measure in the same basis.
"""
sifted_key(prot::BBM92Prot) = [r.outcomeA for r in prot._log if r.basisA === r.basisB]

"""
$TYPEDSIGNATURES

The quantum bit error rate of a [`BBM92Prot`](@ref) run, as the fraction of sifted rounds
in which the two outcomes disagree. Returns `NaN` when no round has been sifted yet.

On noiseless pairs this is zero. Under the intercept-resend attacker of `eavesdrop=true` it
approaches `0.25`.
"""
function qber(prot::BBM92Prot)
    sifted = [r for r in prot._log if r.basisA === r.basisB]
    isempty(sifted) && return NaN
    return count(r -> r.outcomeA != r.outcomeB, sifted) / length(sifted)
end
