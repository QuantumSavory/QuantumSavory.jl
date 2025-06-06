import QuantumSavory

"""
Perform a projective measurement on the given slot of the given register.
with the given noise parameter ξ.

`project_traceout!(reg, slot, [stateA, stateB]; ξ)` performs a projective measurement,
projecting on either `stateA` or `stateB`, returning the index of the subspace
on which the projection happened or the opposite subspace with probability ξ.
It assumes the list of possible states forms a basis for the Hilbert space. 
The Hilbert space of the register is automatically shrunk.

A basis object can be specified on its own as well, e.g.
`project_traceout!(reg, slot, basis; ξ)`.
"""
function project_traceout!(r::QuantumSavory.RegRef, basis; time=nothing, ξ::Float64=0.0, rng::AbstractRNG=Random.GLOBAL_RNG)
    result = QuantumSavory.project_traceout!(r, basis; time=time)
    if rand(rng) < ξ
        result = (result % 2) + 1
    end
    return result
end
