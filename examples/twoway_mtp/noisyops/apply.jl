function noise(state::QuantumOptics.Operator, indices)
    mixed_state = QuantumSymbolics.express(QuantumSavory.IdentityOp(QuantumOptics.basis(state)) / length(QuantumOptics.basis(state)))

    if !isa(QuantumOptics.basis(state), QuantumInterface.CompositeBasis)
        return mixed_state
    elseif length(indices) == length(QuantumOptics.basis(state).bases)
        return mixed_state
    else
        mixed_basis = QuantumInterface.CompositeBasis(QuantumOptics.basis(state).bases[indices])
        mixed_state = QuantumSymbolics.express(QuantumSavory.IdentityOp(mixed_basis) / length(mixed_basis))
        traced_state = QuantumOptics.ptrace(state, indices)

        bit_order = vcat([i for i in 1:length(QuantumOptics.basis(state).bases) if !(i in indices)], indices)
        perm = [findfirst(==(x), bit_order) for x in 1:length(bit_order)]

        perfect_state = QuantumOptics.:⊗(traced_state, mixed_state)
        noisy_state = QuantumOptics.permutesystems(perfect_state, perm)

        return noisy_state
    end
end

function apply!(state::QuantumOptics.Operator, indices, operation::QuantumOptics.Operator; ϵ_g::Float64=0.0)
    op = QuantumOpticsBase.is_apply_shortcircuit(state, indices, operation) ? operation : QuantumOptics.embed(QuantumOptics.basis(state), indices, operation)
    state.data = ((1-ϵ_g)*(op*state*op') + ϵ_g*noise(state, indices)).data
    return state
end
function apply!(state::QuantumOptics.Ket, indices, operation::QuantumOptics.Operator; ϵ_g::Float64=0.0)
    ϵ_g > 0.0 && return apply!(QuantumOptics.dm(state), indices, operation; ϵ_g)

    op = QuantumOpticsBase.is_apply_shortcircuit(state, indices, operation) ? operation : QuantumOptics.embed(QuantumOptics.basis(state), indices, operation)
    state.data = (op*state).data
    return state
end
apply!(state::QuantumOptics.Ket, indices, operation::T; ϵ_g::Float64=0.0) where {T<:QuantumInterface.AbstractSuperOperator} = apply!(QuantumInterface.dm(state), indices, operation; ϵ_g)
# function apply!(state::QuantumOptics.Operator, indices, operation::T; ϵ_g::Float64=0.0) where {T<:QuantumInterface.AbstractSuperOperator}
#     if QuantumOpticsBase.is_apply_shortcircuit(state, indices, operation)
#         state.data = (operation*state).data
#         return state
#     else
#         error("`apply!` does not yet support QuantumOptics.embedding superoperators acting only on a subsystem of the given state")
#     end
# end


function apply!(state, indices::Base.AbstractVecOrTuple{Int}, operation::QuantumSymbolics.Symbolic{QuantumInterface.AbstractOperator}; ϵ_g::Float64=0.0)
    repr = QuantumSavory.default_repr(state)
    apply!(state, indices, QuantumSymbolics.express(operation, repr, QuantumSymbolics.UseAsOperation()); ϵ_g)
end
function apply!(state, indices::Base.AbstractVecOrTuple{Int}, operation::QuantumSymbolics.Symbolic{QuantumInterface.AbstractSuperOperator}; ϵ_g::Float64=0.0)
    repr = QuantumSavory.default_repr(state)
    apply!(state, indices, QuantumSymbolics.express(operation, repr, QuantumSymbolics.UseAsOperation()); ϵ_g)
end
function apply!(regs::Vector{QuantumSavory.Register}, indices::Base.AbstractVecOrTuple{Int}, operation::QuantumSymbolics.Symbolic{QuantumInterface.AbstractOperator}; time=nothing, ϵ_g::Float64=0.0)
    invoke(apply!, Tuple{Vector{QuantumSavory.Register}, Base.AbstractVecOrTuple{Int}, Any}, regs, indices, operation; time, ϵ_g)
end
function apply!(regs::Vector{QuantumSavory.Register}, indices::Base.AbstractVecOrTuple{Int}, operation::QuantumSymbolics.Symbolic{QuantumInterface.AbstractSuperOperator}; time=nothing, ϵ_g::Float64=0.0)
    invoke(apply!, Tuple{Vector{QuantumSavory.Register}, Base.AbstractVecOrTuple{Int}, Any}, regs, indices, operation; time, ϵ_g)
end


"""
Apply a given operation on the given set of register slots.

`apply!([regA, regB], [slot1, slot2], Gates.CNOT)` would apply a CNOT gate
on the content of the given registers at the given slots.
The appropriate representation of the gate is used,
depending on the formalism under which a quantum state is stored in the given registers.
The Hilbert spaces of the registers are automatically joined if necessary.
"""
function apply!(regs::Vector{QuantumSavory.Register}, indices::Base.AbstractVecOrTuple{Int}, operation; time=nothing, ϵ_g::Float64=0.0)
    max_time = maximum((r.accesstimes[i] for (r,i) in zip(regs,indices)))
    if !isnothing(time)
        time<max_time && error("The simulation was commanded to apply $(operation) at time t=$(time) although the current simulation time is higher at t=$(max_time). Consider using locks around the offending operations.")
        max_time = time
    end
    QuantumSavory.uptotime!(regs, indices, max_time)
    QuantumSavory.subsystemcompose(regs,indices)
    state = regs[1].staterefs[indices[1]].state[]
    state_indices = [r.stateindices[i] for (r,i) in zip(regs, indices)]
    state = apply!(state, state_indices, operation; ϵ_g)
    regs[1].staterefs[indices[1]].state[] = state
    return regs, max_time
end
apply!(refs::Vector{QuantumSavory.RegRef}, operation; time=nothing, ϵ_g::Float64=0.0) = apply!([r.reg for r in refs], [r.idx for r in refs], operation; time, ϵ_g)
apply!(refs::NTuple{N,QuantumSavory.RegRef}, operation; time=nothing, ϵ_g::Float64=0.0) where {N} = apply!([r.reg for r in refs], [r.idx for r in refs], operation; time, ϵ_g) # TODO temporary array allocated here
apply!(ref::QuantumSavory.RegRef, operation; time=nothing, ϵ_g::Float64=0.0) = apply!([ref.reg], [ref.idx], operation; time, ϵ_g)
