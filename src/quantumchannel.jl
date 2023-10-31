"""
QuantumChannel for transmitting qubits as `RegRef`s from one register to another in a quantum protocol simulation, 
with a channel delay and under the influence of a background process.
The function `put!` is used to put the `RegRef` containing the qubit in the channel, which can then be received by
the receiving register after a specified delay using the take! method in a synchronous way.

```jldoctest
julia> using QuantumSavory; using ResumableFunctions; using ConcurrentSim

julia> bell = (Z1⊗Z1 + Z2⊗Z2)/sqrt(2.0); regA = Register(2); regB = Register(2); initialize!((regA[1], regB[2]), bell);

julia> sim = Simulation();

julia> queue = DelayQueue{RegRef}(sim, 10.0)
DelayQueue{RegRef}(QueueStore{RegRef, Int64}, 10.0)

julia> qc = QuantumChannel(queue)
QuantumChannel(Qubit(), DelayQueue{RegRef}(QueueStore{RegRef, Int64}, 10.0), nothing)

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
    queue::ConcurrentSim.DelayQueue{RegRef}
    background::Any
end

function QuantumChannel(queue::ConcurrentSim.DelayQueue{RegRef}, background=nothing)
    QuantumChannel(Qubit(), queue, background)
end

function Base.put!(qc::QuantumChannel, rref::RegRef, Δt=nothing)
    if xor(isnothing(qc.background), isnothing(Δt))
        throw(ArgumentError(lazy"""
        Either both background and Δt should be nothing or both should be initialized to appropriate values
        """))
    elseif !isnothing(Δt) # if both are not nothing
        uptotime!(rref.reg.staterefs[rref.idx], rref.reg.stateindices[rref.idx], qc.background, Δt)
    end

    put!(qc.queue, rref)
end

# should we mandate that rref_rec.reg is not initialized beforehand
# should other register attributes of the sent regref be copied over like reprs[idx], backgrounds[idx], accesstimes[idx], env and locks[idx]
@resumable function Base.take!(env, qc::QuantumChannel, rref_rec::RegRef)
    rref = @yield take!(qc.queue)

    rref_rec.reg.staterefs[rref_rec.idx] = rref.reg.staterefs[rref.idx]
    rref_rec.reg.stateindices[rref_rec.idx] = rref.reg.stateindices[rref.idx]

    # update the stateref
    sref = rref.reg.staterefs[rref.idx]
    sref.registers[rref.idx] = rref_rec.reg
    sref.registerindices[rref.idx] = rref_rec.idx

    # erase the state from the sending register
    rref.reg.staterefs[rref.idx] = nothing
    rref.reg.stateindices[rref.idx] = 0
end