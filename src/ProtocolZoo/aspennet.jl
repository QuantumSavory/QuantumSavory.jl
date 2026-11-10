"""
Experimental clocked, lossless ASPEN-Net model with Fock levels `0:4`; not public API.

For stored Bell pairs, start both sources together and omit `LocalMeasurement`.
With `heralding_probability=0.1` and `repetitions=100`, each buffer supplies one
photon in more than 99.99% of periods. The examples use `reflectivity=0.1` for about
9.5% heralding success per period and 94.7% Bell fidelity. The `Source` default,
`reflectivity=0.01`, gives about 1% success and 99.5% fidelity. Higher reflectivity
sends more photons to the hub, increasing success but also two-photon false heralds.
This tradeoff makes the digital twin easier to explore at the cost of fidelity.
Only the first hub detector heralds success, fixing the Bell phase to
`(|10⟩ + |01⟩)/√2`; accepting both ports would require a phase correction.

With one photon supplied by each source, the local Fock-basis results are below.
Here `0` means vacuum and `1` means a click; the hub also thresholds photon counts.

| Hub result | End-node clicks | Cause |
|:---|:---|:---|
| Success | `(1,0)` or `(0,1)` | One photon reaches the first hub port; one stays local. The good Bell component gives anticoincidence. |
| Success | `(0,0)` | Both photons reach the hub and bunch at the first port. This false herald leaves local vacuum. |
| Failure | `(1,1)` | Both photons stay local (coincidence); the hub sees vacuum. |
| Failure | `(1,0)` or `(0,1)` | The hub photon exits the rejected second port. |
| Failure | `(0,0)` | Both photons bunch at the rejected second port. |

A successful herald with `(1,1)` is impossible in this model. If a source supplies
no photon, its local record is absent, not zero; the other source can still trigger
a herald without a Bell pair. With neither source supplying a photon, no event is logged.
Local measurements consume the pair; anticoincidence alone does not prove entanglement.

There is no fiber loss between nodes and hub, and source emissions have no
higher-photon amplitudes. Two-photon arrivals from the two sources are included.
TODO: include fiber loss and source brightness with higher-photon emissions.
"""
module AspenNet

using QuantumSavory
using QuantumSavory: @domain
import QuantumSavory: Tag
using QuantumSavory.ProtocolZoo: AbstractProtocol, protocol_log_context
import QuantumSavory.ProtocolZoo: _protocol_nodes, protocol_catalog_metadata
using ConcurrentSim
using ResumableFunctions
using DocStringExtensions

const _repr = QuantumOpticsRepr(cutoff=4)
_fock_basis() = [express(FockState(n), _repr) for n in 0:_repr.cutoff]

"""Work over `(start_tick, stop_tick] * tick_duration`. Both tick indices must be
nonnegative multiples of `repetitions`. Send to the source's message buffer before
the start time. Invalid or late commands are consumed and discarded."""
struct Start <: AbstractTag
    start_tick::Int
    stop_tick::Int
end
Tag(t::Start) = Tag(Start, t.start_tick, t.stop_tick)
Base.show(io::IO, t::Start) = print(io, "AspenNet start/stop ticks $(t.start_tick)/$(t.stop_tick)")

"""Marks a local mode released at `period * repetitions * tick_duration`."""
struct TimeTag <: AbstractTag
    period::Int
end
Tag(t::TimeTag) = Tag(TimeTag, t.period)
Base.show(io::IO, t::TimeTag) = print(io, "AspenNet period $(t.period)")

"""Hub threshold-detector result for one buffer period, sent to both sources.
`success` is a click only at the first output, including two-photon false heralds."""
struct Confirmation <: AbstractTag
    period::Int
    success::Bool
end
Tag(t::Confirmation) = Tag(Confirmation, t.period, Int(t.success))
Base.show(io::IO, t::Confirmation) = print(io, "AspenNet period $(t.period): ", t.success ? "success" : "failure")

function _period(tick_duration, repetitions)
    @domain isfinite(tick_duration) && tick_duration > 0
    @domain repetitions > 0
    period = tick_duration * repetitions
    @domain isfinite(period)
    return period
end

function _delay(net, source, hub)
    delay = qchannel(net, source=>hub).queue.delay
    @domain isfinite(delay) && delay >= 0
    delay == qchannel(net, hub=>source).queue.delay == channel(net, source=>hub).delay == channel(net, hub=>source).delay || throw(ArgumentError("AspenNet requires equal quantum and classical delays in both directions"))
    return delay
end

"""
$TYPEDEF

Buffer the first heralded photon, then split it between a local memory and the hub.
Wait for a [`Start`](@ref) message before working. The ideal lossless buffer has
availability `1-(1-heralding_probability)^repetitions`; one draw per buffer is
equivalent to keeping only the first success on the shared tick grid. Releases
occur at global multiples of `repetitions * tick_duration`.

The precomputed Fock state is `sqrt(1-r)|10⟩ + sqrt(r)|01⟩`, local mode first.
Use `Qumode()` slots with `QuantumOpticsRepr(cutoff=4)`.
Memory slots and the outgoing quantum channel are dedicated to this source.
If all configured memories are occupied or locked, discard that period's photon.
Buffer loss, dark counts, and phase noise are outside this initial model.

$FIELDS
"""
@kwdef struct Source <: AbstractProtocol
    "simulation clock, normally inferred from `net`"
    sim::Simulation
    "network of registers"
    net::RegisterNet
    "source node"
    node::Int
    "central hub node"
    hub::Int
    "local memory slot indices reserved for this source"
    memories::Vector{Int} = [1]
    "shared time between generation attempts"
    tick_duration::Float64 = 1.0
    "generation attempts per buffer period"
    repetitions::Int = 100
    "single-photon heralding probability per tick"
    heralding_probability::Float64 = 0.1
    "beamsplitter probability of sending the photon toward the hub"
    reflectivity::Float64 = 0.01

    function Source(sim, net, node, hub, memories, tick_duration, repetitions, heralding_probability, reflectivity)
        sim === get_time_tracker(net) || throw(ArgumentError("simulation must belong to the network"))
        _period(tick_duration, repetitions)
        _delay(net, node, hub)
        @domain 0 <= heralding_probability <= 1
        @domain 0 <= reflectivity <= 1
        @domain !isempty(memories) && allunique(memories)
        all(i -> 1 <= i <= length(net[node]), memories) || throw(ArgumentError("invalid memory slots"))
        new(sim, net, node, hub, memories, tick_duration, repetitions, heralding_probability, reflectivity)
    end
end
Source(net::RegisterNet, node::Int, hub::Int; kwargs...) = Source(; sim=get_time_tracker(net), net, node, hub, kwargs...)

"""
$TYPEDEF

Immediately measure each occupied slot marked with [`TimeTag`](@ref) in the number
basis, remove the tag, and free the slot. `_log` stores measurement time, release
period, memory slot, and `number` (0 for vacuum, 1 for any nonvacuum outcome).
Photon counts are discarded after this thresholding. No entangled pair is retained.

$FIELDS
"""
@kwdef struct LocalMeasurement <: AbstractProtocol
    "simulation clock, normally inferred from `net`"
    sim::Simulation
    "network of registers"
    net::RegisterNet
    "node whose time-tagged memories are measured"
    node::Int
    "internal measurement history; storage is not a public interface"
    _log::Vector{@NamedTuple{t::Float64, period::Int, slot::Int, number::Int}} = []

    function LocalMeasurement(sim, net, node, _log)
        sim === get_time_tracker(net) || throw(ArgumentError("simulation must belong to the network"))
        net[node] # Validate the node before scheduling a process.
        new(sim, net, node, _log)
    end
end
LocalMeasurement(net::RegisterNet, node::Int; kwargs...) = LocalMeasurement(; sim=get_time_tracker(net), net, node, kwargs...)

"""
$TYPEDEF

Measure arriving modes at each global buffer deadline plus link delay.
All four directed quantum/classical links must have the same constant delay.
Missing modes are vacuum. A balanced beamsplitter erases the input path. Measure
both outputs in the Fock basis, then distinguish vacuum from any nonvacuum outcome.
Accept a click at the first output only, fixing the retained Bell phase; bunched
two-photon events can still give false heralds. Store
`(t, period, success)` in `_log` and send [`Confirmation`](@ref) over both classical
links. Periods without either input are skipped without a record or confirmation;
an arriving vacuum mode still produces a measurement result. Confirmations remain
in the sources' buffers for analysis; local measurements do not wait for them.

Use two dedicated hub slots and incoming channels; start this protocol before the
first source release. It runs until the simulation stops.

$FIELDS
"""
@kwdef struct Hub <: AbstractProtocol
    "simulation clock, normally inferred from `net`"
    sim::Simulation
    "network of registers"
    net::RegisterNet
    "hub node"
    node::Int
    "two source nodes, in the same order as `slots`"
    sources::Tuple{Int,Int}
    "two dedicated input memory slots"
    slots::Tuple{Int,Int} = (1, 2)
    "shared time between generation attempts"
    tick_duration::Float64 = 1.0
    "generation attempts per buffer period"
    repetitions::Int = 100
    "internal threshold-detection history; storage is not a public interface"
    _log::Vector{@NamedTuple{t::Float64, period::Int, success::Bool}} = []

    function Hub(sim, net, node, sources, slots, tick_duration, repetitions, _log)
        sim === get_time_tracker(net) || throw(ArgumentError("simulation must belong to the network"))
        _period(tick_duration, repetitions)
        @domain allunique(sources)
        @domain allunique(slots)
        all(i -> 1 <= i <= length(net[node]), slots) || throw(ArgumentError("invalid hub slots"))
        _delay(net, sources[1], node) == _delay(net, sources[2], node) || throw(ArgumentError("both source links must have the same delay"))
        new(sim, net, node, sources, slots, tick_duration, repetitions, _log)
    end
end
Hub(net::RegisterNet, node::Int, sources::Tuple{Int,Int}; kwargs...) = Hub(; sim=get_time_tracker(net), net, node, sources, kwargs...)

_protocol_nodes(p::Source) = (p.node, p.hub)
_protocol_nodes(p::LocalMeasurement) = (p.node,)
_protocol_nodes(p::Hub) = (p.node, p.sources...)
protocol_catalog_metadata(::Type{Source}) = (attachment=:edge, attachment_fields=(node_a=:node, node_b=:hub), required_fields=())
protocol_catalog_metadata(::Type{LocalMeasurement}) = (attachment=:node, attachment_fields=(node=:node,), required_fields=())
protocol_catalog_metadata(::Type{Hub}) = (attachment=:node, attachment_fields=(node=:node,), required_fields=(:sources,))

@resumable function (p::Source)()
    period_duration = _period(p.tick_duration, p.repetitions)
    available = -expm1(p.repetitions * log1p(-p.heralding_probability))
    # TODO: model source brightness, including small higher-photon amplitudes.
    state = express(sqrt(1-p.reflectivity)*(F1⊗F0) + sqrt(p.reflectivity)*(F0⊗F1), _repr)
    flying = Register([Qumode()], [_repr])
    reg = p.net[p.node]
    while true
        msg = @yield querydelete_wait!(messagebuffer(p.net, p.node), Start, ❓, ❓)
        start_tick, stop_tick = msg.tag[2], msg.tag[3]
        start_period, stop_period = start_tick ÷ p.repetitions, stop_tick ÷ p.repetitions
        start_time = start_period*period_duration
        if !(0 <= start_tick < stop_tick && start_tick % p.repetitions == stop_tick % p.repetitions == 0 && now(p.sim) <= start_time)
            @debug "Discarded AspenNet work interval" _group=LOG_GROUPS.protocol event=:interval_discarded protocol_log_context(p)... start_tick stop_tick
            continue
        end
        @yield timeout(p.sim, start_time-now(p.sim))
        for period in (start_period+1):stop_period
            # First-success sampling represents the lossless delay loop.
            success = rand() < available
            @yield timeout(p.sim, period*period_duration-now(p.sim))
            success || continue
            memory = findfirst(i -> !isassigned(reg[i]) && !islocked(reg[i]), p.memories)
            if isnothing(memory)
                @debug "Discarded AspenNet photon without memory" _group=LOG_GROUPS.protocol event=:memory_unavailable protocol_log_context(p)... period
                continue
            end
            # This non-yielding handoff publishes the tag only after transmission.
            slot = reg[p.memories[memory]]
            initialize!((slot, flying[1]), state; time=now(p.sim))
            put!(qchannel(p.net, p.node=>p.hub), flying[1])
            tag!(slot, TimeTag(period))
            @debug "Released AspenNet photon" _group=LOG_GROUPS.protocol event=:photon_released protocol_log_context(p)... period slot=slot.idx
        end
    end
end

@resumable function (p::LocalMeasurement)()
    reg = p.net[p.node]
    basis = _fock_basis()
    while true
        match = @yield query_wait(reg, TimeTag, ❓; assigned=true, locked=false)
        slot = match.slot
        @yield lock(slot)
        match = query(slot, TimeTag, ❓; assigned=true)
        if !isnothing(match)
            period = match.tag[2]
            number = Int(project_traceout!(slot, basis; time=now(p.sim)) != 1)
            untag!(slot, match.id)
            push!(p._log, (t=now(p.sim), period=period, slot=slot.idx, number=number))
            @debug "Measured AspenNet memory" _group=LOG_GROUPS.protocol event=:number_measured protocol_log_context(p)... period slot=slot.idx number
        end
        unlock(slot)
    end
end

@resumable function (p::Hub)()
    duration = _period(p.tick_duration, p.repetitions)
    delay = _delay(p.net, p.sources[1], p.node)
    period = max(1, floor(Int, (now(p.sim)-delay)/duration)+1)
    a, b = p.net[p.node][p.slots[1]], p.net[p.node][p.slots[2]]
    basis = _fock_basis()
    beamsplitter = express(BeamSplitterOp(1/2), _repr)
    while true
        # Lower priority lets all same-time releases and channel arrivals finish.
        @yield timeout(p.sim, period*duration+delay-now(p.sim); priority=-1)
        if !any(source -> isready(qchannel(p.net, source=>p.node).queue.store), p.sources)
            period += 1
            continue
        end
        for (source, slot) in zip(p.sources, (a, b))
            qc = qchannel(p.net, source=>p.node)
            if isready(qc.queue.store)
                @yield take!(qc, slot)
            else
                initialize!(slot, basis[1]; time=now(p.sim))
            end
        end
        apply!((a, b), beamsplitter; time=now(p.sim))
        first_click = project_traceout!(a, basis) != 1
        second_click = project_traceout!(b, basis) != 1
        success = first_click && !second_click
        push!(p._log, (t=now(p.sim), period=period, success=success))
        for source in p.sources
            put!(channel(p.net, p.node=>source), Tag(Confirmation(period, success)))
        end
        @debug "Measured AspenNet hub" _group=LOG_GROUPS.protocol event=:hub_measured protocol_log_context(p)... period success
        period += 1
    end
end

include("aspennet_show.jl")

end # module AspenNet
