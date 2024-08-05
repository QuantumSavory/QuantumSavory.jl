
Register(traits, ::Union{Tuple{}, AbstractVector{Union{}}}) = Register(traits)
subsystemcompose() = error()
project_traceout!(::Union{Ket,Operator}, ::Int, ::Union{Tuple{}, AbstractVector{Union{}}}) = error()
QuantumClifford.apply!(::QuantumClifford.MixedDestabilizer, ::QuantumSavory.QCGateSequence, ::Type{<:QuantumClifford.AbstractSymbolicOperator}) = error()
observable(::Union{Tuple{}, AbstractVector{Union{}}}, ::Base.AbstractVecOrTuple{Int}) = error()
