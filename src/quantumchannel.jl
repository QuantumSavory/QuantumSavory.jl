"""
Quantum channel for transmitting quantum states from one register to another.

Delay and background noise processes are supported.

The function `put!` is used to take the contents of a `RegRef` and put it in the channel.
That state can can then be received by a register (after a delay) using the `take!` method.

```jldoctest
julia> using QuantumSavory, ResumableFunctions, ConcurrentSim

julia> regA = Register(1); regB = Register(1);

julia> initialize!(regA[1], Z1);

julia> sim = Simulation();

julia> qc = QuantumChannel(sim, 10.0) # a delay of 10 units
QuantumChannel{Qubit}(Qubit(), DelayQueue{Register}(ConcurrentSim.QueueStore{Register, Int64}, 10.0), nothing)

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
Register with 1 slots: [ Qubit ]
  Slots:
    nothing
```
"""
struct QuantumChannel{T}
    trait::T
    queue::ConcurrentSim.DelayQueue{Register}
    background::Any
end

QuantumChannel(queue::ConcurrentSim.DelayQueue{Register}, background=nothing, trait=Qubit()) = QuantumChannel(trait, queue, background)

QuantumChannel(env::ConcurrentSim.Simulation, delay, background=nothing, trait=Qubit()) = QuantumChannel(ConcurrentSim.DelayQueue{Register}(env, delay), background, trait)
Register(qc::QuantumChannel) = Register([qc.trait], [qc.background])

function Base.put!(qc::QuantumChannel, rref::RegRef)
    time = ConcurrentSim.now(qc.queue.store.env)
    channel_reg = Register(qc)
    swap!(rref, channel_reg[1]; time)
    uptotime!(channel_reg[1], time+qc.queue.delay)
    put!(qc.queue, channel_reg)
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
