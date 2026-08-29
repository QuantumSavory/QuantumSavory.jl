nsubsystems(state::Gabs.GaussianState) = Gabs.nmodes(state.basis)
nsubsystems(op::Gabs.GaussianUnitary) = Gabs.nmodes(op.basis)
nsubsystems(channel::Gabs.GaussianChannel) = Gabs.nmodes(channel.basis)

subsystemcompose(states::Gabs.GaussianState...) = tensor(states...)
subsystemcompose(ops::Gabs.GaussianUnitary...) = tensor(ops...)
subsystemcompose(channels::Gabs.GaussianChannel...) = tensor(channels...)

const variance_factor = 1e-12

function _preflight_project_traceout(
    state::Gabs.GaussianState, subsys::Int, meas::HomodyneMeasurement
)
    length(meas.angles) == 1 || throw(ArgumentError(
        "Gabs homodyne measurement of one subsystem requires one angle."
    ))
    1 <= subsys <= nsubsystems(state) || throw(BoundsError(state, subsys))
    nothing
end

function project_traceout!(
    state::Gabs.GaussianState, subsys::Int, meas::HomodyneMeasurement
)
    _preflight_project_traceout(state, subsys, meas)
    coordinates, state = Gabs.homodyne(
        state, subsys, meas.angles; squeeze = variance_factor
    )
    result = complex(coordinates[1], coordinates[2])
    if nsubsystems(state) == 1
        return result, nothing
    end
    state = Gabs.ptrace(state, subsys)
    return result, state
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
