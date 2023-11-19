"""
Apply a given operation on the given set of register slots.

`apply!([regA, regB], [slot1, slot2], Gates.CNOT)` would apply a CNOT gate
on the content of the given registers at the given slots.
The appropriate representation of the gate is used,
depending on the formalism under which a quantum state is stored in the given registers.
The Hilbert spaces of the registers are automatically joined if necessary.
"""
function apply!(regs::Vector{Register}, indices::Vector{Int}, operation; time=nothing)
    max_time = maximum((r.accesstimes[i] for (r,i) in zip(regs,indices)))
    if !isnothing(time)
        time<max_time && error("The simulation was commanded to apply $(operation) at time t=$(time) although the current simulation time is higher at t=$(max_time). Consider using locks around the offending operations.")
        max_time = time
    end
    uptotime!(regs, indices, max_time)
    subsystemcompose(regs,indices)
    state = regs[1].staterefs[indices[1]].state[]
    state_indices = [r.stateindices[i] for (r,i) in zip(regs, indices)]
    state = apply!(state, state_indices, operation)
    regs[1].staterefs[indices[1]].state[] = state
    regs, max_time
end
apply!(refs::Vector{RegRef}, operation; time=nothing) = apply!([r.reg for r in refs], [r.idx for r in refs], operation; time)
apply!(refs::NTuple{N,RegRef}, operation; time=nothing) where {N} = apply!([r.reg for r in refs], [r.idx for r in refs], operation; time) # TODO temporary array allocated here
apply!(ref::RegRef, operation; time=nothing) = apply!([ref.reg], [ref.idx], operation; time)
