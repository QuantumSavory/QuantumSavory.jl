import ConcurrentSim

# Smallest N for which two independent buffers are ready with probability ≥ target.
function _aspen_repetitions(p, target)
    p == 1 && return 1
    return setprecision(BigFloat, max(256, 128-exponent(p))) do
        source, coincidence = BigFloat(p), BigFloat(target)
        n = ceil(Int, log1p(-sqrt(coincidence)) / log1p(-source))
        ready(k) = (1-(1-source)^k)^2
        while n > 1 && ready(n-1) ≥ coincidence
            n -= 1
        end
        while ready(n) < coincidence
            n += 1
        end
        n
    end
end

"""
$TYPEDEF

    AspenSchedule(; heralding_prob=0.5, coincidence_prob=0.95, attempt_time=0.001,
        start_time=0.0, period=1.0, rounds=1, arrival_timeout=0.1,
        coincidence_window=arrival_timeout, acknowledgement_timeout=0.2)

Shared global clock for [`AspenSourceProt`](@ref) and [`AspenCentralProt`](@ref).
Pass the same schedule to all three processes and launch them by `start_time`.
Round `k` starts at `start_time + (k-1)*period` and releases its photons after
`repetitions*attempt_time`. Both deadlines are relative to this release.
Channel delays must be strictly inside the deadlines; successive rounds must
not overlap. Delays and the schedule must remain fixed during a run.

$TYPEDFIELDS
"""
struct AspenSchedule
    "independent per-pulse heralding probability in (0,1] for both sources"
    heralding_prob::Float64
    "target probability that both buffers are ready; 1 requires perfect sources"
    coincidence_prob::Float64
    "positive time between source pulses"
    attempt_time::Float64
    "absolute start of buffering in the first round"
    start_time::Float64
    "time between consecutive round starts"
    period::Float64
    "number of scheduled rounds, including busy rounds"
    rounds::Int
    "time from release to the central receive deadline"
    arrival_timeout::Float64
    "maximum separation between the two arrival times"
    coincidence_window::Float64
    "time from release to the common source acknowledgement deadline"
    acknowledgement_timeout::Float64
    "computed minimum buffer depth satisfying (1-(1-heralding_prob)^N)^2 ≥ coincidence_prob"
    repetitions::Int

    function AspenSchedule(; heralding_prob=0.5, coincidence_prob=0.95,
        attempt_time=0.001, start_time=0.0, period=1.0, rounds=1,
        arrival_timeout=0.1, coincidence_window=arrival_timeout, acknowledgement_timeout=0.2)
        @domain 0 < heralding_prob ≤ 1
        @domain 0 < coincidence_prob ≤ 1
        coincidence_prob < 1 || heralding_prob == 1 ||
            throw(ArgumentError("unit coincidence probability requires perfect sources"))
        @domain isfinite(attempt_time) && attempt_time > 0
        @domain isfinite(start_time) && start_time ≥ 0
        @domain isfinite(period) && period > 0
        0 < coincidence_window ≤ arrival_timeout < acknowledgement_timeout < Inf ||
            throw(ArgumentError("require 0 < coincidence_window ≤ arrival_timeout < acknowledgement_timeout < Inf"))
        @domain rounds ≥ 0
        repetitions = _aspen_repetitions(Float64(heralding_prob), Float64(coincidence_prob))
        repetitions*attempt_time + acknowledgement_timeout < period ||
            throw(ArgumentError("period must exceed buffering and acknowledgement time"))
        new(heralding_prob, coincidence_prob, attempt_time, start_time, period, rounds,
            arrival_timeout, coincidence_window, acknowledgement_timeout, repetitions)
    end
end

"""
$TYPEDEF

Classical confirmation sent by [`AspenCentralProt`](@ref). A successful threshold
click can include a two-photon false herald of vacuum. Source memory is always slot 1.

$TYPEDFIELDS
"""
struct AspenHerald <: AbstractTag
    "central node sending the confirmation"
    central_node::Int
    "scheduled round number"
    round::Int
    "other source node"
    remote_node::Int
    "whether the threshold detector heralded success"
    success::Bool
    "whether the receiver must apply a Z phase correction (0 or 1)"
    correction::Int
    "shared nonzero identifier for the successful pair; zero on failure"
    pair_id::EntanglementID
end
Tag(h::AspenHerald) = Tag(AspenHerald, h.central_node, h.round, h.remote_node,
    Int(h.success), h.correction, h.pair_id)
Base.show(io::IO, h::AspenHerald) = print(io,
    "ASPEN round $(h.round) from $(h.central_node): $(h.success ? "success" : "failure")")

const _AspenRecord = @NamedTuple{round::Int, start::Float64, release::Float64,
    complete::Float64, first::Int, outcome::Symbol, pair_id::EntanglementID}

function _aspen_validate(sim, net, schedule, source, central)
    sim === get_time_tracker(net) || throw(ArgumentError("sim must be the network simulation"))
    source != central || throw(ArgumentError("source and central nodes must differ"))
    length(net[source]) ≥ 2 || throw(ArgumentError("each source needs memory and outgoing slots"))
    length(net[central]) == 2 || throw(ArgumentError("the central node needs exactly two slots"))
    0 ≤ qchannel(net, source=>central).queue.delay < schedule.arrival_timeout ||
        throw(ArgumentError("quantum delay must be inside the arrival deadline"))
    0 ≤ channel(net, central=>source).delay < schedule.acknowledgement_timeout-schedule.arrival_timeout ||
        throw(ArgumentError("classical delay must be inside the acknowledgement deadline"))
end

"""
$TYPEDEF

    AspenSourceProt(net, node, centralnode; schedule, central_fraction=0.1)
    AspenSourceProt(sim, net, node, centralnode; schedule, central_fraction=0.1)

Buffer the first heralded photon, split it locally at the scheduled release, and
send the outgoing mode through `qchannel`. Slot 1 is memory; slot 2 is the outgoing
mode. Busy slots skip a round. Owned slots stay locked until the common
acknowledgement deadline, when [`AspenHerald`](@ref) determines tagging or erasure.

Use qubit slots with `QuantumOpticsRepr`. Buffering and local optics are lossless;
the first success is sampled geometrically instead of simulating unused pulses.
The split state is `√(1-r)|10⟩ + √r|01⟩`, with `r=central_fraction`.
Both sources must use the same [`AspenSchedule`](@ref) and splitter fraction.
The source-to-central quantum channels are dedicated to this protocol.

$TYPEDFIELDS
"""
@kwdef struct AspenSourceProt <: AbstractProtocol
    "network simulation"
    sim::Simulation
    "network containing the source and central node"
    net::RegisterNet
    "local source node"
    node::Int
    "central which-path erasure node"
    centralnode::Int
    "global timing and source probability parameters"
    schedule::AspenSchedule
    "probability of sending the photon toward the central node, in [0,1]"
    central_fraction::Float64 = 0.1
    "internal completed-round history; first is zero when no photon was buffered"
    _log::Vector{_AspenRecord} = _AspenRecord[]

    function AspenSourceProt(sim, net, node, centralnode, schedule, central_fraction, _log)
        _aspen_validate(sim, net, schedule, node, centralnode)
        @domain 0 ≤ central_fraction ≤ 1
        new(sim, net, node, centralnode, schedule, central_fraction, _log)
    end
end
AspenSourceProt(sim::Simulation, net::RegisterNet, node::Int, centralnode::Int; kwargs...) =
    AspenSourceProt(; sim, net, node, centralnode, kwargs...)
AspenSourceProt(net::RegisterNet, node::Int, centralnode::Int; kwargs...) =
    AspenSourceProt(get_time_tracker(net), net, node, centralnode; kwargs...)
protocol_catalog_metadata(::Type{AspenSourceProt}) = (
    attachment=:node, attachment_fields=(node=:node,), required_fields=(:centralnode, :schedule))
_protocol_nodes(p::AspenSourceProt) = (p.node, p.centralnode)

"""
$TYPEDEF

    AspenCentralProt(net, node, nodeA, nodeB; schedule)
    AspenCentralProt(sim, net, node, nodeA, nodeB; schedule)

Receive source A and B into exactly two dedicated slots. At the receive deadline,
erase which-path information if both modes arrived within `coincidence_window`;
otherwise discard the partial attempt. Send success or failure independently over
each classical channel. No source memory is accessed by this process.

An effective qubit instrument models ideal threshold detectors and stable phase:
single-photon clicks prepare a Bell state, and two-photon clicks herald vacuum.
Unobserved photon multiplicity is sampled internally, so successful trajectories
average to fidelity `2(1-r)/(2-r)` with click probability `r(2-r)` when both buffers
are ready. Output-mode bunching is not explicitly represented. Dark counts and
buffer loss are omitted; quantum-channel and memory backgrounds still act.

$TYPEDFIELDS
"""
@kwdef struct AspenCentralProt <: AbstractProtocol
    "network simulation"
    sim::Simulation
    "network containing both sources and the central node"
    net::RegisterNet
    "local central node, with two dedicated slots"
    node::Int
    "source whose incoming mode occupies central slot 1"
    nodeA::Int
    "source whose incoming mode occupies central slot 2"
    nodeB::Int
    "same global schedule as both sources"
    schedule::AspenSchedule
    "internal completed-round history"
    _log::Vector{_AspenRecord} = _AspenRecord[]

    function AspenCentralProt(sim, net, node, nodeA, nodeB, schedule, _log)
        nodeA != nodeB || throw(ArgumentError("the two sources must differ"))
        _aspen_validate(sim, net, schedule, nodeA, node)
        _aspen_validate(sim, net, schedule, nodeB, node)
        new(sim, net, node, nodeA, nodeB, schedule, _log)
    end
end
AspenCentralProt(sim::Simulation, net::RegisterNet, node::Int, nodeA::Int, nodeB::Int; kwargs...) =
    AspenCentralProt(; sim, net, node, nodeA, nodeB, kwargs...)
AspenCentralProt(net::RegisterNet, node::Int, nodeA::Int, nodeB::Int; kwargs...) =
    AspenCentralProt(get_time_tracker(net), net, node, nodeA, nodeB; kwargs...)
protocol_catalog_metadata(::Type{AspenCentralProt}) = (
    attachment=:node, attachment_fields=(node=:node,), required_fields=(:nodeA, :nodeB, :schedule))
_protocol_nodes(p::AspenCentralProt) = (p.node, p.nodeA, p.nodeB)

function _aspen_record!(p, round, start, release, outcome; first=0, pair_id=NO_ENTANGLEMENT_ID)
    record = (; round, start, release, complete=now(p.sim), first, outcome, pair_id)
    push!(p._log, record)
    @debug("ASPEN round completed", _group=LOG_GROUPS.protocol,
        event=:aspen_round_completed, protocol_log_context(p)..., record...)
end

_aspen_occupied(slot) = isassigned(slot) || !isnothing(query(slot, EntanglementCounterpart, ❓, ❓, ❓))

@resumable function (p::AspenSourceProt)()
    s = p.schedule
    now(p.sim) ≤ s.start_time || throw(ArgumentError("launch ASPEN processes by start_time"))
    memory, outgoing = p.net[p.node][1], p.net[p.node][2]
    for round in 1:s.rounds
        start = s.start_time + (round-1)*s.period
        release = start + s.repetitions*s.attempt_time
        @yield timeout(p.sim, start-now(p.sim))
        # Reserve local hardware for this slot; busy memories keep their existing pair.
        owned = !any(slot -> islocked(slot) || _aspen_occupied(slot), (memory,outgoing))
        first = 0
        outcome = :busy
        if owned
            @yield lock(memory) & lock(outgoing)
            if !_aspen_occupied(memory) && !_aspen_occupied(outgoing)
                first = s.heralding_prob == 1 ? 1 : rand(Geometric(s.heralding_prob))+1
                first = first ≤ s.repetitions ? first : 0
                outcome = first == 0 ? :no_photon : :timeout
            else
                unlock(memory)
                unlock(outgoing)
                owned = false
            end
        end
        # Keep only the first herald; release the buffered pulse on the global clock.
        @yield timeout(p.sim, release-now(p.sim))
        if first > 0
            r = p.central_fraction
            initialize!((memory, outgoing), sqrt(1-r)*(Z2⊗Z1)+sqrt(r)*(Z1⊗Z2); time=release)
            put!(qchannel(p.net, p.node=>p.centralnode), outgoing)
            @debug("ASPEN photon released", _group=LOG_GROUPS.protocol,
                event=:aspen_photon_released, protocol_log_context(p)..., round, first)
        end
        # Publish only at the agreed deadline, after classical confirmation can arrive.
        @yield timeout(p.sim, release+s.acknowledgement_timeout-now(p.sim))
        herald = querydelete!(messagebuffer(p.net, p.node), AspenHerald, p.centralnode, round, ❓, ❓, ❓, ❓)
        pair_id = NO_ENTANGLEMENT_ID
        if first > 0
            uptotime!(memory, now(p.sim))
            if !isnothing(herald) && herald.tag[5] == 1
                herald.tag[6] == 1 && apply!(memory, Z)
                pair_id = herald.tag[7]
                _tag_entanglement_counterpart!(memory, herald.tag[4], 1, pair_id, p)
                outcome = :success
            else
                traceout!(memory)
                outcome = isnothing(herald) ? :timeout : :failure
            end
        end
        if owned
            unlock(memory)
            unlock(outgoing)
        end
        _aspen_record!(p, round, start, release, outcome; first, pair_id)
    end
end

@resumable function _aspen_receive(sim, qc, slot, deadline)
    # Own the queue event so a missing photon cannot leave a waiter in the next round.
    receive = take!(qc.queue)
    @yield receive | timeout(sim, deadline-now(sim))
    if ConcurrentSim.state(receive) === ConcurrentSim.processed
        incoming = ConcurrentSim.value(receive)
        QuantumSavory.swap!(incoming[1], slot; time=now(sim))
        return now(sim)
    end
    ConcurrentSim.cancel(qc.queue.store, receive)
    return NaN
end

function _aspen_detect!(a, b)
    # Resolve parity first, then erase which-path information within the one-photon sector.
    apply!((a,b), CNOT)
    odd = project_traceout!(b, (Z1,Z2)) == 2
    outcome = project_traceout!(a, odd ? (X1,X2) : (Z1,Z2))
    success = odd || outcome == 2
    correction = odd ? outcome-1 : Int(rand(Bool))
    return success, correction
end

@resumable function (p::AspenCentralProt)()
    s = p.schedule
    now(p.sim) ≤ s.start_time || throw(ArgumentError("launch ASPEN processes by start_time"))
    a, b = p.net[p.node][1], p.net[p.node][2]
    # The central station dedicates its two receive slots for the whole schedule.
    any(slot -> islocked(slot) || _aspen_occupied(slot), (a,b)) &&
        throw(ArgumentError("central receive slots must be free"))
    @yield lock(a) & lock(b)
    any(_aspen_occupied, (a,b)) && throw(ArgumentError("central receive slots must be free"))
    for round in 1:s.rounds
        start = s.start_time + (round-1)*s.period
        release = start + s.repetitions*s.attempt_time
        @yield timeout(p.sim, release-now(p.sim))
        # Receive independently over the two quantum links, with a bounded wait.
        deadline = release+s.arrival_timeout
        receiveA = @process _aspen_receive(p.sim, qchannel(p.net, p.nodeA=>p.node), a, deadline)
        receiveB = @process _aspen_receive(p.sim, qchannel(p.net, p.nodeB=>p.node), b, deadline)
        @yield receiveA & receiveB
        arrivalA, arrivalB = ConcurrentSim.value(receiveA), ConcurrentSim.value(receiveB)
        @yield timeout(p.sim, deadline-now(p.sim))
        # A partial or noncoincident pair is erased; a coincidence enters the eraser.
        success, correction = false, 0
        outcome = :timeout
        if isassigned(a) && isassigned(b)
            if abs(arrivalA-arrivalB) ≤ s.coincidence_window + 8eps(max(arrivalA,arrivalB))
                uptotime!((a,b), now(p.sim))
                success, correction = _aspen_detect!(a,b)
                outcome = success ? :success : :failure
            else
                outcome = :mismatch
            end
        end
        for slot in (a,b)
            isassigned(slot) && traceout!(slot)
        end
        # Only classical heralds tell the sources whether to keep their memories.
        pair_id = success ? fresh_entanglement_id() : NO_ENTANGLEMENT_ID
        put!(channel(p.net, p.node=>p.nodeA), Tag(AspenHerald(p.node, round, p.nodeB, success, correction, pair_id)))
        put!(channel(p.net, p.node=>p.nodeB), Tag(AspenHerald(p.node, round, p.nodeA, success, 0, pair_id)))
        _aspen_record!(p, round, start, release, outcome; pair_id)
    end
    unlock(a)
    unlock(b)
end
