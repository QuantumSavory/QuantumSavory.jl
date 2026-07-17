"""
Calculate the expectation value of a quantum observable on the given register and slot.

`observable([regA, regB], [slot1, slot2], obs)` would calculate the expectation value
of the `obs` observable (using the appropriate formalism, depending on the state
representation in the given registers).
"""
function observable(regs::Base.AbstractVecOrTuple{Register}, indices::Base.AbstractVecOrTuple{Int}, obs; something=nothing, time=nothing)
    staterefs = StateRef[]
    for (r, i) in zip(regs, indices)
        ref = r.staterefs[i]
        isnothing(ref) && return something
        push!(staterefs, ref)
    end
    !isnothing(time) && uptotime!(regs, indices, time)
    unique_staterefs, offsets = unique_staterefs_with_offsets(staterefs)
    state = length(unique_staterefs) == 1 ? unique_staterefs[1].state[] :
            subsystemcompose([s.state[] for s in unique_staterefs]...)
    state_indices = [r.stateindices[i] + offsets[r.staterefs[i]]
                     for (r,i) in zip(regs, indices)]
    observable(state, state_indices, obs)
end
observable(refs::Base.AbstractVecOrTuple{RegRef}, obs; something=nothing, time=nothing) = observable(map(r->r.reg, refs), map(r->r.idx, refs), obs; something, time)
observable(ref::RegRef, obs; something=nothing, time=nothing) = observable([ref.reg], [ref.idx], obs; something, time)
