export lindbladop

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

function lindbladop(b::AbstractBackground, basis) # shortcircuit for backgrounds that work on a single basis
    lindbladop(b)
end

function lindbladop(T1::T1Decay)
    1/√T1.t1 * _lh
end

function lindbladop(d::AmplitudeDamping, basis)
    1/√d.τ * destroy(basis)
end

function lindbladop(T2::T2Dephasing) # TODO pay attention to the √2 necessary to match to kraus operators
    1 / √(2*T2.t2) * _z
end

function lindbladop(D::Depolarization)
    1/√D.τ .* (0.5 * [_x, _y, _z])
end

function lindbladop(P::PauliNoise)
    # TODO
end
