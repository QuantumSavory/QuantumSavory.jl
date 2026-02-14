nsubsystems(state::Gabs.GaussianState) = Gabs.nmodes(state.basis)
nsubsystems(op::Gabs.GaussianUnitary) = Gabs.nmodes(op.basis)
nsubsystems(channel::Gabs.GaussianChannel) = Gabs.nmodes(channel.basis)

subsystemcompose(states::Gabs.GaussianState...) = tensor(states...)
subsystemcompose(ops::Gabs.GaussianUnitary...) = tensor(ops...)
subsystemcompose(channels::Gabs.GaussianChannel...) = tensor(ops...)

function project_traceout!(
    state::Gabs.GaussianState, subsys::Int, meas::HomodyneMeasurement
)
    res, state = Gabs.homodyne(state, subsys, meas.angles; squeeze = meas.squeeze)
    return res, state
end

# feels like a hacky workaround because `apply!(state, indices::Base.AbstractVecOrTuple{Int}, operation::Symbolic{AbstractOperator})`
# should probably forward `AbstractRepresentation` subtypes from `Register` objects rather than call `default_repr`.
function default_repr(state::Gabs.GaussianState)
    return GabsRepr(typeof(state.basis))
end
function default_repr(state::Gabs.GaussianUnitary)
    return GabsRepr(typeof(state.basis))
end
function default_repr(state::Gabs.GaussianChannel)
    return GabsRepr(typeof(state.basis))
end