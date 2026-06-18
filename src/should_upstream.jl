using QuantumInterface: AbstractBra

nsubsystems(x::Symbolic{T}) where {T<:QObj} = QuantumSymbolics.isexpr(x) ? sum(nsubsystems, arguments(x)) : nsubsystems(basis(x))
nsubsystems(s::AbstractBra) = nsubsystems(basis(s))

purity(state::AbstractOperator) = real(tr(state * state))
purity(state::StateVector) = purity(dm(state))