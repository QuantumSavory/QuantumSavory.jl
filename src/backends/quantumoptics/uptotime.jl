function uptotime!(state::StateVector, idx::Int, background, Δt)
    state = dm(state)
    uptotime!(state, idx, background, Δt)
end

function _embedded_lindblad_operators(state, state_indices, backgrounds)
    base = basis(state)
    iscomposite = base isa CompositeBasis
    lindbladians = AbstractOperator[]
    for (i, bg) in zip(state_indices, backgrounds)
        isnothing(bg) && continue
        subsystem_basis = iscomposite ? base.bases[i] : base
        for op in lindbladop(bg, subsystem_basis)
            push!(lindbladians, iscomposite ? embed(base, [i], op) : op)
        end
    end
    lindbladians
end

function uptotime!(state::MCKet, idx::Int, background, Δt)
    b = basis(state)
    iscomposite = b isa CompositeBasis
    Ks = krausops(background, Δt, b)
    if isnothing(Ks)
        lindbladians = _embedded_lindblad_operators(state, (idx,), (background,))
        hamiltonian = zero(identityoperator(b))
        _, sol = timeevolution.mcwf([0, Δt], state.ket, hamiltonian, lindbladians)
        return MCKet(sol[end])
    end

    branches = map(Ks) do k
        embedded_k = iscomposite ? embed(b, [idx], k) : k
        embedded_k * state.ket
    end
    probabilities = norm.(branches) .^ 2
    total_probability = sum(probabilities)
    @assert total_probability ≈ 1

    threshold = rand() * total_probability
    branch = something(findfirst(>(threshold), cumsum(probabilities)), lastindex(branches))
    MCKet(normalize(branches[branch]))
end

function uptotime!(state::Operator, idx::Int, background, Δt)
    nstate = zero(state)
    tmpl = zero(state)
    tmpr = zero(state)
    b = basis(state)
    e = isa(b,CompositeBasis) # TODO make this more elegant with multiple dispatch
    Ks = krausops(background, Δt, b)
    if isnothing(Ks) # TODO turn this into a dispatch on a trait of having a kraus representations
        lindbladians = _embedded_lindblad_operators(state, (idx,), (background,))
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
The Kraus operators for a T₁T₂ process.

Of note, this is **not** the same as having "on top of each other"
T₁ noise and then an additional "dephasing" noise.
T₁ is causing dephasing of its own, and T₂ (transverse relaxation time) includes
dephasing from T₁ and pure dephasing Tᵩ where `1/Tᵩ = 1/T₂ - 1/(2T₁)`.
See https://qiskit-community.github.io/qiskit-experiments/manuals/characterization/tphi.html for more.
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

"""Kraus operators have freedom in how they can be picked -- this function exists to provide known alternative implementations for use in testing."""
function krausops_alt end

"""Alternative Krauss operator for testing"""
struct KrausAltWrapper <: AbstractBackground
    noise
end

function krausops(wrapper::KrausAltWrapper, args)
    return krausops_alt(wrapper.noise, args)
end

function krausops_alt(T1T2::T1T2Noise, Δt)
    (; t1, t2) = T1T2
    γ = 1-exp(-Δt/t1)
    tᵩ = t1 * t2 / (2t1 - t2)
    λ = 1-exp(-Δt/tᵩ)
    k1 = _ll + √((1-γ)*(1-λ)) * _hh
    k2 = √((1-γ)*λ) * _hh
    k3 = √(γ) * _lh
    [k1, k2, k3]
end
