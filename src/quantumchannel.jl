"""
QuantumChannel for transmitting qubits as `RegRef`s from one register to another in a quantum protocol simulation, 
with a channel delay and under the influence of a background process.
The function `put!` is used to put the `RegRef` containing the qubit in the channel, which can then be received by
the receiving register after a specified delay using the take! method in a synchronous way.

```jldoctest
julia> using QuantumSavory; using ResumableFunctions; using ConcurrentSim

julia> bell = (Z1⊗Z1 + Z2⊗Z2)/sqrt(2.0); regA = Register(2); regB = Register(2); initialize!((regA[1], regB[2]), bell);

julia> sim = Simulation();

julia> queue = DelayQueue{Register}(sim, 10.0)
DelayQueue{Register}(QueueStore{Register, Int64}, 10.0)

julia> qc = QuantumChannel(queue)
QuantumChannel(Qubit(), DelayQueue{Register}(QueueStore{Register, Int64}, 10.0), nothing)

julia> @resumable function alice_node(env, qc)
            println("Putting Alice's qubit in the channel at ", now(env))
            put!(qc, regA[1])
        end
alice_node (generic function with 1 method)

julia> @resumable function bob_node(env, qc)
            @yield @process take!(env, qc, regB[1]) # wait for the process with delay to complete
            println("Taking the qubit from alice at ", now(env))
        end
bob_node (generic function with 1 method)

julia> @process alice_node(sim, qc); @process bob_node(sim, qc);

julia> run(sim)
Putting Alice's qubit in the channel at 0.0
Taking the qubit from alice at 10.0

julia> regA
Register with 2 slots: [ Qubit | Qubit ]
  Slots:
    nothing
    nothing

julia> regB
Register with 2 slots: [ Qubit | Qubit ]
  Slots:
    Subsystem 1 of QuantumOpticsBase.Ket 12382959472027850978
    Subsystem 2 of QuantumOpticsBase.Ket 12382959472027850978
```
"""
struct QuantumChannel
  trait::Qubit
  queue::ConcurrentSim.DelayQueue{Register}
  background::Any
end

QuantumChannel(queue::ConcurrentSim.DelayQueue{Register}, background=nothing) = QuantumChannel(Qubit(), queue, background)

QuantumChannel(env::ConcurrentSim.Simulation, delay, background=nothing) = QuantumChannel(ConcurrentSim.DelayQueue{Register}(env, delay), background)

function Base.put!(qc::QuantumChannel, rref::RegRef)
  if !isnothing(qc.background)
      uptotime!(rref, ConcurrentSim.now(qc.queue.store.env))
  end

  channel_reg = Register(1)
  channel_reg.backgrounds[1] = qc.background
  channel_reg.traits[1] = qc.trait
  swap!(rref, channel_reg[1])

  if !isnothing(qc.background)
      uptotime!(channel_reg[1], qc.queue.delay)
  end

  put!(qc.queue, channel_reg)
end


@resumable function Base.take!(env, qc::QuantumChannel, rref_rec::RegRef)
  if isassigned(rref_rec.reg, rref_rec.idx)
      throw("Receiving register index already initialized")
  end
  channel_reg = @yield take!(qc.queue)

  swap!(rref_rec, channel_reg[1])
end