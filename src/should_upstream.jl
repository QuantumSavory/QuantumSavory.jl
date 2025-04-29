nsubsystems(x::Symbolic{T}) where {T<:QObj} = QuantumSymbolics.isexpr(x) ? sum(nsubsystems, arguments(x)) : nsubsystems(basis(x))
