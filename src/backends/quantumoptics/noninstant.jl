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
    res = lindbladop(b)
    # Handle case where lindbladop returns multiple operators (like T1T2Noise)
    if isa(res, Tuple)
        return res
    else
        return res
    end
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
- `L₂ = (1/√(2T₂*)) Z` for pure dephasing (if T₂ < 2T₁)

where `1/T₂* = 1/T₂ - 1/(2T₁)`
"""
function lindbladop(noise::T1T2Noise)
    # Calculate T₂* (pure dephasing time)
    t2star_inv = 1/noise.t2 - 1/(2*noise.t1)

    if t2star_inv <= 0
        # T₂ ≈ 2T₁, only amplitude damping
        return (1/√noise.t1 * _lh,)
    end

    t2star = 1/t2star_inv
    # Return both Lindblad operators as a tuple
    (1/√noise.t1 * _lh, 1/√(2*t2star) * _z)
end
