
Register(traits, ::Union{Tuple{}, AbstractVector{Union{}}}) = Register(traits)
subsystemcompose() = error()
project_traceout!(::Union{Ket,Operator}, ::Int, ::Union{Tuple{}, AbstractVector{Union{}}}) = error()
observable(::Union{Tuple{}, AbstractVector{Union{}}}, ::Base.AbstractVecOrTuple{Int}) = error()
