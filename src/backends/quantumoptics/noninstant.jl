function apply_noninstant!(state::Operator, state_indices::Vector{Int}, operation::ConstantHamiltonianEvolution, backgrounds)
    Δt = operation.duration
    base = basis(state)
    e = isa(base, CompositeBasis)
    lindbladians = []
    for (i, bg) in zip(state_indices, backgrounds)
        if !isnothing(bg)
            ops = lindbladop(bg, base)
            # Ensure ops is always a list
            ops = typeof(ops) <: AbstractArray ? ops : [ops]
            # Embed if necessary
            ops = e ? [embed(base, [i], op) for op in ops] : ops
            append!(lindbladians, ops)
        end
    end
    ham = express(operation.hamiltonian, QOR)
    ham = e ? embed(base, state_indices, ham) : ham
    _, sol = timeevolution.master([0, Δt], state, ham, lindbladians)
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
