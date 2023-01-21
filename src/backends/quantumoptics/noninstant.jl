export lindbladop

function apply_noninstant!(state::Operator, state_indices::Vector{Int}, operation::ConstantHamiltonianEvolution, backgrounds)
    Δt = operation.duration
    base = basis(state)
    e = isa(base,CompositeBasis)
    lindbladians = [e ? embed(base,[i],lindbladop(bg)) : lindbladop(bg) for (i,bg) in zip(state_indices,backgrounds) if !isnothing(bg)]
    ham = express(operation.hamiltonian, QOR)
    ham = e ? embed(base,state_indices,ham) : ham
    _, sol = timeevolution.master([0,Δt], state, ham, lindbladians)
    sol[end]
end

function apply_noninstant!(state::Ket, state_indices::Vector{Int}, operation::ConstantHamiltonianEvolution, backgrounds)
    apply_noninstant!(dm(state), state_indices, operation, backgrounds)
end

function lindbladop(T1::T1Decay)
    1/√T1.t1 * _lh
end

function lindbladop(T2::T2Dephasing) # TODO pay attention to the √2 necessary to match to kraus operators
    1 / √(2*T2.t2) * _z
end

function lindbladop(D::Depolarization)
end

function lindbladop(P::PauliNoise)
end
