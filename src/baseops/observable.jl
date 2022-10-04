export observable

"""
Calculate the expectation value of a quantum observable on the given register and slot.

`observable([regA, regB], [slot1, slot2], obs)` would calculate the expectation value
of the `obs` observable (using the appropriate formalism, depending on the state
representation in the given registers).
"""
function observable(regs::Vector{Register}, indices::Vector{Int}, obs, something=nothing; time=nothing) # TODO weird split between positional and keyword arguments
    staterefs = [r.staterefs[i] for (r,i) in zip(regs, indices)]
    # TODO it should still work even if they are not represented in the same state
    (any(isnothing, staterefs) || !all(s->s===staterefs[1], staterefs)) && return something
    !isnothing(time) && uptotime!(regs, indices, time)
    state = staterefs[1].state[]
    state_indices = [r.stateindices[i] for (r,i) in zip(regs, indices)]
    observable(state, state_indices, obs)
end
observable(refs::Vector{RegRef}, obs, something=nothing; time=nothing) = observable([r.reg for r in refs], [r.idx for r in refs], obs, something; time)
observable(refs::NTuple{N,RegRef}, obs, something=nothing; time=nothing) where {N} = observable((r.reg for r in refs), (r.idx for r in refs), obs, something; time)
observable(ref::RegRef, obs, something=nothing; time=nothing) = observable([ref.reg], [ref.idx], obs, something; time)
