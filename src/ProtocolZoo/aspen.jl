"""
$TYPEDEF

Central station confirmation for one [`AspenEntanglerProt`](@ref) attempt.
Success means a detector click, which can include a false herald of vacuum.

$TYPEDFIELDS
"""
struct AspenHerald <: AbstractTag
    "unique attempt identifier, also used as the successful pair's identifier"
    pair_id::EntanglementID
    "whether the central threshold detector clicked"
    success::Bool
end
Tag(h::AspenHerald) = Tag(AspenHerald, h.pair_id, Int(h.success))
Base.show(io::IO, h::AspenHerald) = print(io, "ASPEN attempt $(h.pair_id): $(h.success ? "success" : "failure")")

const _AspenRecord = @NamedTuple{round::Int, start::Float64, release::Float64,
    herald::Float64, complete::Float64, firstA::Int, firstB::Int, outcome::Symbol, pair_id::EntanglementID}

# (1-(1-p)^N)^2 ≥ coincidence; the rewritten numerator avoids cancellation near 1.
function _aspen_repetitions(p, coincidence)
    p == 1 && return 1
    return ceil(Int, (log1p(-coincidence) - log1p(sqrt(coincidence))) / log1p(-p))
end

"""
$TYPEDEF

    AspenEntanglerProt(net, nodeA, nodeB, centralnode; kwargs...)
    AspenEntanglerProt(sim, net, nodeA, nodeB, centralnode; kwargs...)

Minimal ASPEN-Net distribution between two source/memory nodes and a central
which-path eraser. One process coordinates all three nodes on the network clock.
Each source retains only its first heralded photon in `N` attempts, where the
smallest `N` satisfies `(1-(1-heralding_prob)^N)^2 ≥ coincidence_prob`.
Buffering starts at `start_time + (round-1)*period`; release is `N*attempt_time`
later, with pulse `k` at `start + k*attempt_time`. Busy or missed slots are skipped,
never shifted. Both memory slots remain
locked until both [`AspenHerald`](@ref) messages arrive through the classical
channels, then are tagged or erased together.

The optical model assumes indistinguishable photons, stable phase, ideal threshold
detectors, lossless buffers/transmission/loading, and implicit detector-dependent
phase correction. With both photons available and central fraction `r`, a click
has probability `r*(2-r)` and prepares `F|Ψ⁺⟩⟨Ψ⁺| + (1-F)|00⟩⟨00|`, where
`F=2*(1-r)/(2-r)` and `|Ψ⁺⟩=(|01⟩+|10⟩)/√2`. A lone photon clicks with probability
`r` and leaves vacuum. Thus a successful herald need not imply a perfect Bell pair.
The conditional memory state is initialized at release; memory backgrounds then
act during flight and confirmation. Use `QuantumOpticsRepr` for these mixed states.
Optical modes, losses, dark counts, and distributed scheduling are not modeled.

$TYPEDFIELDS
"""
@kwdef struct AspenEntanglerProt <: AbstractProtocol
    "time-and-schedule tracker; must be the network's simulation"
    sim::Simulation
    "network with direct links from both source nodes to the central station"
    net::RegisterNet
    "first source/memory node"
    nodeA::Int
    "second source/memory node"
    nodeB::Int
    "central which-path erasure and heralding node"
    centralnode::Int
    "reserved memory slot at node A"
    slotA::Int = 1
    "reserved memory slot at node B"
    slotB::Int = 1
    "independent per-pulse source heralding probability, in (0,1]"
    heralding_prob::Float64 = 0.5
    "target probability that both buffers contain a photon; 1 requires perfect sources"
    coincidence_prob::Float64 = 0.95
    "beam splitter probability of sending a photon to the central station, in [0,1]"
    central_fraction::Float64 = 0.1
    "positive time between source pulses"
    attempt_time::Float64 = 0.001
    "common photon flight time from either source to the central station"
    photon_time::Float64 = 0.0
    "absolute start of the first buffering slot"
    start_time::Float64 = 0.0
    "fixed slot spacing, at least the buffering plus photon flight time"
    period::Float64 = 1.0
    "number of scheduled slots, including skipped slots"
    rounds::Int = 1
    "internal completed-slot history; first photon attempt is 0 when absent"
    _log::Vector{_AspenRecord} = _AspenRecord[]

    function AspenEntanglerProt(sim, net, nodeA, nodeB, centralnode, slotA, slotB,
        heralding_prob, coincidence_prob, central_fraction, attempt_time, photon_time,
        start_time, period, rounds, _log)
        @domain 0 < heralding_prob ≤ 1
        @domain 0 < coincidence_prob ≤ 1
        coincidence_prob < 1 || heralding_prob == 1 ||
            throw(ArgumentError("unit coincidence probability requires perfect sources"))
        @domain 0 ≤ central_fraction ≤ 1
        @domain isfinite(attempt_time) && attempt_time > 0
        @domain isfinite(photon_time) && photon_time ≥ 0
        @domain isfinite(start_time) && start_time ≥ 0
        @domain isfinite(period) && period > 0
        period ≥ _aspen_repetitions(heralding_prob, coincidence_prob)*attempt_time + photon_time ||
            throw(ArgumentError("period must cover buffering and photon flight"))
        @domain rounds ≥ 0
        nodes = (nodeA, nodeB, centralnode)
        @domain length(unique(nodes)) == 3
        for node in nodes
            sim === get_time_tracker(net[node]) ||
                throw(ArgumentError("all nodes must use the network simulation"))
        end
        sim === get_time_tracker(net) || throw(ArgumentError("sim must be the network simulation"))
        1 ≤ slotA ≤ length(net[nodeA]) || throw(ArgumentError("slotA is out of bounds"))
        1 ≤ slotB ≤ length(net[nodeB]) || throw(ArgumentError("slotB is out of bounds"))
        channel(net, centralnode=>nodeA), channel(net, centralnode=>nodeB)
        new(sim, net, nodeA, nodeB, centralnode, slotA, slotB, heralding_prob,
            coincidence_prob, central_fraction, attempt_time, photon_time,
            start_time, period, rounds, _log)
    end
end

AspenEntanglerProt(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int, centralnode::Int; kwargs...) =
    AspenEntanglerProt(; sim, net, nodeA, nodeB, centralnode, kwargs...)
AspenEntanglerProt(net::RegisterNet, nodeA::Int, nodeB::Int, centralnode::Int; kwargs...) =
    AspenEntanglerProt(get_time_tracker(net), net, nodeA, nodeB, centralnode; kwargs...)

protocol_catalog_metadata(::Type{AspenEntanglerProt}) = (
    attachment=:node, attachment_fields=(node=:centralnode,), required_fields=(:nodeA, :nodeB),
)
_protocol_nodes(p::AspenEntanglerProt) = (p.nodeA, p.nodeB, p.centralnode)

function _aspen_record!(p, round, start, outcome; release=NaN, herald=NaN, firstA=0, firstB=0, pair_id=NO_ENTANGLEMENT_ID)
    record = (; round, start, release, herald, complete=now(p.sim), firstA, firstB, outcome, pair_id)
    push!(p._log, record)
    @debug("ASPEN slot completed", _group=LOG_GROUPS.protocol,
        event=:aspen_slot_completed, protocol_log_context(p)..., record...)
end

_aspen_occupied(slot) = isassigned(slot) || !isnothing(query(slot, EntanglementCounterpart, ❓, ❓, ❓))
# Treat a few rounding units as the same clock tick, without drifting the schedule.
_aspen_late(time, start) = time-start > 8eps(max(time, start))

@resumable function (p::AspenEntanglerProt)()
    a, b = p.net[p.nodeA][p.slotA], p.net[p.nodeB][p.slotB]
    repetitions = _aspen_repetitions(p.heralding_prob, p.coincidence_prob)
    for round in 1:p.rounds
        start = p.start_time + (round-1)*p.period
        if _aspen_late(now(p.sim), start)
            _aspen_record!(p, round, start, :late)
            continue
        end
        @yield timeout(p.sim, max(0.0, start-now(p.sim)))
        if islocked(a) || islocked(b) || _aspen_occupied(a) || _aspen_occupied(b)
            _aspen_record!(p, round, start, :busy)
            continue
        end
        @yield lock(a) & lock(b)
        # Revalidate after acquiring resources: another process may have won the slots.
        if _aspen_late(now(p.sim), start) || _aspen_occupied(a) || _aspen_occupied(b)
            unlock(a)
            unlock(b)
            _aspen_record!(p, round, start, _aspen_late(now(p.sim), start) ? :late : :busy)
            continue
        end
        firstA = rand(Geometric(p.heralding_prob)) + 1
        firstB = rand(Geometric(p.heralding_prob)) + 1
        firstA = firstA ≤ repetitions ? firstA : 0
        firstB = firstB ≤ repetitions ? firstB : 0
        release = start + repetitions*p.attempt_time
        @yield timeout(p.sim, max(0.0, release-now(p.sim)))
        release = now(p.sim)
        readyA, readyB = firstA > 0, firstB > 0
        r = p.central_fraction
        click_prob = readyA && readyB ? r*(2-r) : (readyA || readyB ? r : 0.0)
        success = rand() < click_prob
        if success
            fidelity = readyA && readyB ? 2*(1-r)/(2-r) : 0.0
            state = fidelity*SProjector((Z1⊗Z2 + Z2⊗Z1)/sqrt(2)) + (1-fidelity)*SProjector(Z1⊗Z1)
        else
            state = (readyA ? Z2 : Z1) ⊗ (readyB ? Z2 : Z1)
        end
        # The conditional instrument is sampled here, while memories are inaccessible.
        initialize!((a,b), state; time=release)
        pair_id = fresh_entanglement_id()
        @debug("ASPEN photons released", _group=LOG_GROUPS.protocol,
            event=:aspen_photons_released, protocol_log_context(p)...,
            round, pair_id, repetitions, firstA, firstB)
        @yield timeout(p.sim, p.photon_time)
        herald = now(p.sim)
        put!(channel(p.net, p.centralnode=>p.nodeA), Tag(AspenHerald(pair_id, success)))
        put!(channel(p.net, p.centralnode=>p.nodeB), Tag(AspenHerald(pair_id, success)))
        @debug("ASPEN central herald", _group=LOG_GROUPS.protocol,
            event=:aspen_herald_sent, protocol_log_context(p)..., round, pair_id, success)
        receiveA = querydelete_wait!(messagebuffer(p.net, p.nodeA), AspenHerald, pair_id, Int(success))
        receiveB = querydelete_wait!(messagebuffer(p.net, p.nodeB), AspenHerald, pair_id, Int(success))
        @yield receiveA & receiveB
        # Publish reciprocal metadata together so trackers cannot miss early updates.
        uptotime!((a,b), now(p.sim))
        if success
            _tag_entanglement_counterpart!(a, p.nodeB, b.idx, pair_id, p)
            _tag_entanglement_counterpart!(b, p.nodeA, a.idx, pair_id, p)
        else
            traceout!(a,b)
        end
        unlock(a)
        unlock(b)
        _aspen_record!(p, round, start, success ? :success : :failure;
            release, herald, firstA, firstB, pair_id)
    end
end
