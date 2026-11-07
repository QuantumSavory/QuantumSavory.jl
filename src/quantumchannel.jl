"""
$TYPEDEF

Quantum channel for transmitting quantum states from one register to another.

Delay and background noise processes are supported.

The function `put!` is used to take the contents of a `RegRef` and put it in the channel.
That state can then be received by a register (after a delay) using the `take!` method.
Use [`channel_delay`](@ref), `isready(qc)`, and [`onchange`](@ref) to inspect or
observe the channel without receiving its state.

```jldoctest
julia> using QuantumSavory, ResumableFunctions, ConcurrentSim

julia> regA = Register(1); regB = Register(1);

julia> initialize!(regA[1], Z1);

julia> sim = Simulation();

julia> qc = QuantumChannel(sim, 10.0); # a delay of 10 units

julia> @resumable function alice_node(env, qc)
            println("Putting Alice's qubit in the channel at ", now(env))
            put!(qc, regA[1])
        end
alice_node (generic function with 1 method)

julia> @resumable function bob_node(env, qc)
            @yield take!(qc, regB[1])
            println("Taking the qubit from alice at ", now(env))
        end
bob_node (generic function with 1 method)

julia> @process alice_node(sim, qc); @process bob_node(sim, qc);

julia> run(sim)
Putting Alice's qubit in the channel at 0.0
Taking the qubit from alice at 10.0

julia> regA
Register  with 1 slots: [ Qubit ]
  Slots:
    nothing
```
"""
struct QuantumChannel{T}
    trait::T
    queue::ConcurrentSim.DelayQueue{Register}
    background::Any
    arrival::ChangeNotifier
    function QuantumChannel(queue::ConcurrentSim.DelayQueue{Register}, background=nothing, trait::T=Qubit()) where T
        new{T}(trait, queue, background, ChangeNotifier(queue.store.env))
    end
end

QuantumChannel(env::ConcurrentSim.Simulation, delay, background=nothing, trait=Qubit()) = QuantumChannel(ConcurrentSim.DelayQueue{Register}(env, delay), background, trait)
Register(qc::QuantumChannel) = Register([qc.trait], [qc.background])

"""
    channel_delay(ch)

Return the configured propagation delay of a direct classical or quantum channel,
in simulation time units. Use with [`channel`](@ref), [`qchannel`](@ref), or a
standalone [`QuantumChannel`](@ref). Forwarding handles for nonadjacent nodes do
not have a single link delay and are not supported.

For classical reception, prefer [`messagebuffer`](@ref) and [`querydelete_wait!`](@ref):
the destination buffer already receives from each incoming classical channel.
"""
function channel_delay end
channel_delay(qc::QuantumChannel) = qc.queue.delay

"""
    isready(qc::QuantumChannel)

Return whether an arrived quantum state is available for `take!(qc, slot)` now.
States still in transit do not count; an arriving vacuum mode does count.
This check does not consume or reserve the state. Recheck after yielding.
"""
Base.isready(qc::QuantumChannel) = isready(qc.queue.store)

"""
    onchange(qc::QuantumChannel)

Return a yieldable notification of a future arrival. The call registers before
returning, wakes all observers, and neither consumes nor reserves the state.
Arrivals before the call are not replayed. Check `isready(qc)` before waiting
and again after waking:

```julia
while !isready(qc)
    @yield onchange(qc)
end
@yield take!(qc, slot)
```

For a single receiver with a known destination, `@yield take!(qc, slot)` already
waits for the next state. Notifications can be composed with `|` and `&`, just
like register and message-buffer notifications. An arrival notification alone
does not establish that other arrivals at the same timestamp have finished.
"""
onchange(qc::QuantumChannel) = lock(qc.arrival)

function Base.put!(qc::QuantumChannel, rref::RegRef)
    time = ConcurrentSim.now(qc.queue.store.env)
    channel_reg = Register(qc)
    swap!(rref, channel_reg[1]; time)
    uptotime!(channel_reg[1], time+channel_delay(qc))
    return _put_with_notification(qc.queue, channel_reg, qc.arrival)
end

@resumable function post_take_qc(env, take_event, rref)
    channel_reg = @yield take_event
    if isassigned(rref)
        error("A take! operation is being performed on a QuantumChannel in order to swap the state into a Register, but the target register slot is not empty (it is already initialized).")
    end
    swap!(channel_reg[1], rref; time=now(env))
end

function Base.take!(qc::QuantumChannel, rref::RegRef)
    take_event = take!(qc.queue)
    @process post_take_qc(qc.queue.store.env, take_event, rref)
end
