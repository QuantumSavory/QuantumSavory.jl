
import QuantumClifford

# TODO: solve piracy committed by the following methods, which account to all piracies in the package

function apply!(state, indices::Base.AbstractVecOrTuple{Int}, operation::Symbolic{AbstractOperator})
    repr = default_repr(state)
    apply!(state, indices, express(operation, repr, UseAsOperation()))
end

function apply!(state, indices::Base.AbstractVecOrTuple{Int}, operation::Symbolic{AbstractSuperOperator})
    repr = default_repr(state)
    apply!(state, indices, express(operation, repr, UseAsOperation()))
end

function apply!(regs::Vector{Register}, indices::Base.AbstractVecOrTuple{Int}, operation::Symbolic{AbstractOperator}; time=nothing)
    invoke(apply!, Tuple{Vector{Register}, Base.AbstractVecOrTuple{Int}, Any}, regs, indices, operation; time)
end

function apply!(regs::Vector{Register}, indices::Base.AbstractVecOrTuple{Int}, operation::Symbolic{AbstractSuperOperator}; time=nothing)
    invoke(apply!, Tuple{Vector{Register}, Base.AbstractVecOrTuple{Int}, Any}, regs, indices, operation; time)
end

function apply!(r::QuantumClifford.Register, indices::Base.AbstractVecOrTuple{Int}, operation::Symbolic{AbstractOperator}; time=nothing)
    invoke(apply!, Tuple{QuantumClifford.Register, Base.AbstractVecOrTuple{Int}, Any}, r, indices, operation; time)
end

function apply!(r::QuantumClifford.Register, indices::Base.AbstractVecOrTuple{Int}, operation::Symbolic{AbstractSuperOperator}; time=nothing)
    invoke(apply!, Tuple{QuantumClifford.Register, Base.AbstractVecOrTuple{Int}, Any}, r, indices, operation; time)
end