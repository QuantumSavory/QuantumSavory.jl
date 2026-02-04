function uptotime!(state::StateVector, idx::Int, background, Δt)
    state = dm(state)
    uptotime!(state, idx, background, Δt)
end

function uptotime!(state::Operator, idx::Int, background, Δt)
    nstate = zero(state)
    tmpl = zero(state)
    tmpr = zero(state)
    b = basis(state)
    e = isa(b,CompositeBasis) # TODO make this more elegant with multiple dispatch
    Ks = krausops(background, Δt, b)
    if isnothing(Ks) # TODO turn this into a dispatch on a trait of having a kraus representations
        # TODO code repetition with apply_noninstant!
        L = lindbladop(background,b)
        # Handle tuple of Lindblad operators (e.g., T1T2Noise)
        lindbladians = if isa(L, Tuple)
            [e ? embed(b,[idx],l) : l for l in L]
        else
            [e ? embed(b,[idx],L) : L]
        end
        _, sol = timeevolution.master([0,Δt], state, identityoperator(b), lindbladians)
        nstate.data .= sol[end].data
    else
        for k in Ks
            k = e ? embed(b,[idx],k) : k # TODO lazy product would be better maybe
            mul!(tmpl,k,state,1,0) # TODO there must be a prettier way to do this
            mul!(tmpr,tmpl,k',1,0)
            nstate.data .+= tmpr.data
        end
    end
    @assert abs(tr(nstate)) ≈ 1. # TODO maybe put under a debug flag
    nstate
end

# TODO these should not be necessary, just use QuantumSymbolics
const _b2 = SpinBasis(1//2)
const _h = spindown(_b2) # TODO is this a good decision... look at how clumsy the kraus ops are
const _s₊ = (_l+_h)/√2
const _s₋ = (_l-_h)/√2
const _i₊ = (_l+im*_h)/√2
const _i₋ = (_l-im*_h)/√2
const _lh = sigmap(_b2)
const _ll = projector(_l)
const _hh = projector(_h)
const _id = identityoperator(_b2)
const _z = sigmaz(_b2)
const _x = sigmax(_b2)
const _y = sigmay(_b2)
const _Id = identityoperator(_b2)
const _hadamard = (sigmaz(_b2)+sigmax(_b2))/√2
const _cnot = _ll⊗_Id + _hh⊗_x
const _cphase = _ll⊗_Id + _hh⊗_z
const _phase = _ll + im*_hh
const _iphase = _ll - im*_hh

"""
For a given background noise type, provide the corresponding Kraus operators, in a QuantumOptics.jl representation.

See also: [`paulinoise`](@ref), [`lindbladop`](@ref)
"""
function krausops end

function krausops(b::AbstractBackground, Δt, basis) # shortcircuit for backgrounds that work on a single basis
    return krausops(b, Δt)
end

"""
The Kraus operators for a T₁ process

- `A₁ = |0⟩⟨0| + √(1-γ) |1⟩⟨1|`
- `A₂ = √γ |0⟩⟨1|`
- `λ = 1 - exp(-Δt/T₁)`
"""
function krausops(T1::T1Decay, Δt)
    p = exp(-Δt/T1.t1) # TODO check this
    [√(1-p) * _lh, √p * _hh + _ll]
end

"""
The Kraus operators for a T₂ process

One option is the following (more popular in the literature):
- `P₁ = |0⟩⟨0| + √(1-λ) |1⟩⟨1|`
- `P₂ = √λ |1⟩⟨1|`
- `λ = 1 - exp(-2Δt/T₂)`

An equivalent option is (more convenient when converting to a Pauli error channel):
- `P₁′ = √(1-p/2) I`
- `P₂′ = √(p/2) Z`
- `p = 1 - exp(-Δt/T₂)`

These two options are equivalent under a unitary transformation. We implement the second one.
"""
function krausops(T2::T2Dephasing, Δt)
    p = 1-exp(-Δt/T2.t2)
    [√(1-p/2) * _id, √(p/2) * _z]
end

function krausops(d::AmplitudeDamping, Δt, basis) # https://quantumcomputing.stackexchange.com/questions/6828/amplitude-damping-of-a-harmonic-oscillator
    nothing # TODO strictly speaking this is not necessary as we can always fall back to the lindbladians
end

"""
The Kraus operators for depolarization are
`√(1-3p/4) I, √p/2 * X, √p/2 * Y, √p/2 Z`
"""
function krausops(D::Depolarization, Δt)
    p = 1-exp(-Δt/D.τ)
    [√(1-3p/4) * _id, √(p)/2 * _x, √(p)/2 * _y, √(p)/2 * _z]
end

function krausops(P::PauliNoise)
    nothing # TODO strictly speaking this is not necessary as we can always fall back to the lindbladians
end

"""
The Kraus operators for T₁T₂ are obtained by composing T1 with pure dephasing (if T₂ < 2T₁))
"""
function krausops(T1T2::T1T2Noise, Δt)
    p = exp(-Δt/T1T2.t1)
    kraus_T1 = [√(1-p) * _lh, √p * _hh + _ll]

    # Pure dephasing rate: 1/Tphi = 1/T2 - 1/(2T1)
    Tᵩ_inv = 1/T1T2.t2 - 1/(2*T1T2.t1)

    if Tᵩ_inv <= 0 # no pure dephasing
        return kraus_T1
    end

    Tᵩ = 1/Tᵩ_inv
    pphi = 1 - exp(-Δt/Tᵩ)
    kraus_dephase = [√(1 - pphi/2) * _id, √(pphi/2) * _z]

    [F*E for F in kraus_dephase for E in kraus_T1]
end
