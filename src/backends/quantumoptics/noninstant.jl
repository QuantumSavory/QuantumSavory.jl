function apply_noninstant!(state::Operator, state_indices::Vector{Int}, operation::ConstantHamiltonianEvolution, backgrounds)
    Δt = operation.duration
    base = basis(state)
    e = isa(base,CompositeBasis)
    lindbladians = []
    for (i,bg) in zip(state_indices,backgrounds)
        if !isnothing(bg)
            ops = lindbladop(bg)
            # Handle both single operators and tuples of operators
            if isa(ops, Tuple)
                for op in ops
                    push!(lindbladians, e ? embed(base,[i],op) : op)
                end
            else
                push!(lindbladians, e ? embed(base,[i],ops) : ops)
            end
        end
    end
    ham = express(operation.hamiltonian, QOR)
    ham = e ? embed(base,state_indices,ham) : ham
    _, sol = timeevolution.master([0,Δt], state, ham, lindbladians)
    sol[end]
end

function apply_noninstant!(state::Ket, state_indices::Vector{Int}, operation::ConstantHamiltonianEvolution, backgrounds)
    apply_noninstant!(dm(state), state_indices, operation, backgrounds)
end

"""
For a given background noise type, provide the corresponding Lindblad collapse operator, in a QuantumOptics.jl representation.

See also: [`paulinoise`](@ref), [`krausops`](@ref)
"""
function lindbladop end

function lindbladop(b::AbstractBackground, basis) # shortcircuit for backgrounds that work on a single basis
    lindbladop(b)
end

"`1/√T₁ |0⟩⟨1|`"
function lindbladop(T1::T1Decay)
    1/√T1.t1 * _lh
end

"`1/√τ â`"
function lindbladop(d::AmplitudeDamping, basis)
    1/√d.τ * destroy(basis)
end

"`1/√(2T₂) Z`"
function lindbladop(T2::T2Dephasing)
    1 / √(2*T2.t2) * _z
end

function lindbladop(D::Depolarization)
    error("we do not have lindblad operators implemented for Depolarization")
end

function lindbladop(P::PauliNoise)
    error("we do not have lindblad operators implemented for PauliNoise")
end

"""
Lindblad operators for combined T₁ and T₂ noise.

Returns a tuple of Lindblad operators:
- `L₁ = (1/√T₁) |0⟩⟨1|` for amplitude damping
- `L₂ = (1/√(2Tᵩ)) Z` for pure dephasing (if T₂ < 2T₁)

where `1/Tᵩ = 1/T₂ - 1/(2T₁)`
"""
function lindbladop(T1T2::T1T2Noise)
    Tᵩ_inv = 1/T1T2.t2 - 1/(2*T1T2.t1)

    if Tᵩ_inv <= 0
        return (1/√T1T2.t1 * _lh,)
    end

    Tᵩ = 1/Tᵩ_inv
    (1/√T1T2.t1 * _lh, 1/√(2*Tᵩ) * _z)
end
