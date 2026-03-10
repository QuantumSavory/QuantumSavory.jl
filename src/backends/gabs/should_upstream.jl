function apply!(
    state::Gabs.GaussianState,
    indices::Base.AbstractVecOrTuple{Int},
    operation::Union{Gabs.GaussianUnitary,Gabs.GaussianChannel}
)
    embedded_op = Gabs.embed(state.basis, indices, operation)
    apply!(state, embedded_op)
    return state
end
