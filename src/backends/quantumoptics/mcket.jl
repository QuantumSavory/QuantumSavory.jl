"""A pure-state QuantumOptics ket carrying Monte Carlo trajectory semantics."""
struct MCKet{K<:Ket}
    ket::K
end

Base.copy(state::MCKet) = MCKet(copy(state.ket))

basis(state::MCKet) = basis(state.ket)
nsubsystems(state::MCKet) = nsubsystems(state.ket)
ispadded(::MCKet) = false
default_repr(::MCKet) = QuantumMCRepr()

QuantumSymbolics.express(state::MCKet, ::QuantumMCRepr) = state
QuantumSymbolics.express(state::MCKet, ::QuantumOpticsRepr) = state.ket

function apply!(state::MCKet, indices, operation::Operator)
    MCKet(apply!(state.ket, indices, operation))
end

observable(state::MCKet, indices, operation) = observable(state.ket, indices, operation)

function project_traceout!(state::MCKet, stateindex::Int, measurement_basis)
    result, newstate = project_traceout!(state.ket, stateindex, measurement_basis)
    result, newstate isa Ket ? MCKet(newstate) : newstate
end

function subsystemcompose(states::MCKet...)
    MCKet(tensor((state.ket for state in states)...))
end

function subsystemcompose(states::Union{Ket,MCKet}...)
    tensor((state isa MCKet ? state.ket : state for state in states)...)
end

subsystemcompose(state::MCKet, operation::Operator) = tensor(dm(state.ket), operation)
subsystemcompose(operation::Operator, state::MCKet) = tensor(operation, dm(state.ket))

# Partial trace leaves the pure-state trajectory manifold.
traceout!(state::MCKet, index::Int) = ptrace(state.ket, index)

function Base.show(io::IO, state::MCKet)
    print(io, "MCKet(")
    show(io, state.ket)
    print(io, ")")
end
