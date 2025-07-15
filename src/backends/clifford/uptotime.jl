function uptotime!(state::QuantumClifford.MixedDestabilizer, idx::Int, background, Δt)
    cumprob = 1.0
    r = rand()
    for (prob, op) in paulinoise(background, Δt)
        cumprob -= prob
        if r > cumprob
            QuantumClifford.apply!(state, op(idx))
            break
        end
    end
    state
end

"""
For a given background noise type, provide the corresponding (potentially twirled) Pauli operators and the probabilities for the operators to act, in a QuantumClifford.jl representation.

See also: [`krausops`](@ref), [`lindbladop`](@ref)
"""
function paulinoise end

"""
The Pauli operator and probability of its application for a T₂ process.

`(1-exp(-Δt/T₂)) / 2` and `Z`
"""
function paulinoise(T2::T2Dephasing, Δt)
    p = 1-exp(-Δt/T2.t2)
    ((p/2, QuantumClifford.sZ),)
end

"""
The Pauli operator and probability of its application for a Depolarization process.

`((p/4, X), (p/4, Y), (p/4, Z))` for `p = 1-exp(-Δt/τ)`
"""
function paulinoise(D::Depolarization, Δt)
    p = 1-exp(-Δt/D.τ)
    ((p/4, QuantumClifford.sX), (p/4, QuantumClifford.sY), (p/4, QuantumClifford.sZ))
end

function paulinoise(P::PauliNoise)
    error("we do not have pauli operators implemented for PauliNoise")
end
