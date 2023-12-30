function apply!(state, indices, operation::Symbolic{AbstractOperator})
    repr = default_repr(state)
    apply!(state, indices, express(operation, repr, UseAsOperation()))
end

function apply!(state, indices, operation::Symbolic{AbstractSuperOperator})
    repr = default_repr(state)
    apply!(state, indices, express(operation, repr, UseAsOperation()))
end
