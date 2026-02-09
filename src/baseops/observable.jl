"""
Calculate the expectation value of a quantum observable on the given register and slot.

`observable([regA, regB], [slot1, slot2], obs)` would calculate the expectation value
of the `obs` observable (using the appropriate formalism, depending on the state
representation in the given registers).
"""
function observable(regs::Base.AbstractVecOrTuple{Register}, indices::Base.AbstractVecOrTuple{Int}, obs; something=nothing, time=nothing)
    @show regs
    @show indices
    staterefs = [r.staterefs[i] for (r,i) in zip(regs, indices)]
    # TODO it should still work even if they are not represented in the same state
    @show staterefs
    @show any(isnothing, staterefs)
    @show !all(s->s===staterefs[1], staterefs)
    (any(isnothing, staterefs) || !all(s->s===staterefs[1], staterefs)) && return something
    !isnothing(time) && uptotime!(regs, indices, time)
    state = staterefs[1].state[]
    state_indices = [r.stateindices[i] for (r,i) in zip(regs, indices)]
    @show state_indices
    observable(state, state_indices, obs)
end
observable(refs::Base.AbstractVecOrTuple{RegRef}, obs; something=nothing, time=nothing) = observable(map(r->r.reg, refs), map(r->r.idx, refs), obs; something, time)
observable(ref::RegRef, obs; something=nothing, time=nothing) = observable([ref.reg], [ref.idx], obs; something, time)
