export AbstractNoninstantOperation, NonInstantGate, ConstantHamiltonianEvolution

abstract type AbstractNoninstantOperation end

"""Represents an gate applied instantaneously followed by a waiting period. See also [`ConstantHamiltonianEvolution`](@ref)."""
struct NonInstantGate <: AbstractNoninstantOperation
    gate
    duration # TODO assert larger than zero
end

function apply!(regs::Vector{Register}, indices::Vector{Int}, operation::NonInstantGate; time=nothing)
    _, new_time = apply!(regs, indices, operation.gate; time)
    uptotime!(regs, indices, new_time+operation.duration)
    regs, new_time+operation.duration
end

"""Represents a Hamiltonian being applied for the given duration. See also [`NonInstantGate`](@ref)."""
struct ConstantHamiltonianEvolution <: AbstractNoninstantOperation
    hamiltonian
    duration # TODO assert larger than zero
end

function apply!(regs::Vector{Register}, indices::Vector{Int}, operation::ConstantHamiltonianEvolution; time=nothing) # TODO very significant code repetition with the general purpose apply!
    max_time = maximum((r.accesstimes[i] for (r,i) in zip(regs,indices)))
    if !isnothing(time)
        time<max_time && error("The simulation was commanded to apply $(operation) at time t=$(time) although the current simulation time is higher at t=$(max_time). Consider using locks around the offending operations.")
        max_time = time
    end
    uptotime!(regs, indices, max_time)
    subsystemcompose(regs,indices)
    state = regs[1].staterefs[indices[1]].state[]
    state_indices = [r.stateindices[i] for (r,i) in zip(regs, indices)]
    state = apply_noninstant!(state, state_indices, operation, [r.backgrounds[i] for (r,i) in zip(regs, indices)]) # This is the only different line
    regs[1].staterefs[indices[1]].state[] = state
    end_time = overwritetime!(regs, indices, max_time+operation.duration) # and this line is new in comparison too
    regs, end_time
end
