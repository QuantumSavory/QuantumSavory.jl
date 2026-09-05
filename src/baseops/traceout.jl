ispadded(::Nothing) = false # TODO consider removing this and reworking the functions that depend on it. E.g., a reason to have it when performing a project_traceout measurement on a state that contains only one subsystem

function removebackref!(s::StateRef, i) # To be used only with something that updates s.state[]
    padded = ispadded(s.state[])
    for (r,ri) in zip(s.registers, s.registerindices)
        isnothing(r) && continue
        if r.stateindices[ri] == i
            r.staterefs[ri] = nothing
            r.stateindices[ri] = 0
        elseif !padded && r.stateindices[ri] > i
            r.stateindices[ri] -= 1
        end
    end
    if padded
        s.registerindices[i] = 0
        s.registers[i] = nothing
    else
        deleteat!(s.registerindices, i)
        deleteat!(s.registers, i)
    end
    s
end

"""
    _traceout_state(state, i)

Backend adapter for removing subsystem `i` from the state stored by a [`StateRef`](@ref).
Its return value must follow the storage contract reported by `ispadded`. For an
unpadded state, native storage must no longer contain that subsystem so that
[`removebackref!`](@ref) can renumber the surviving register slots consistently.

The default delegates to the backend's `traceout!`. Backends whose `traceout!` uses a
different storage contract must specialize this adapter. For example,
QuantumClifford's in-place `traceout!` reduces the stabilizer information but retains
the traced qubit's tableau columns, so the Clifford specialization uses `ptrace` to
return a physically smaller tableau.

On the other hand, `traceout!` for Gabs Gaussian states and QuantumOptics state
vectors already delegates to `ptrace`, as does the QuantumOptics operator method, so
these backends return physically smaller states. The Monte Carlo backend wraps a
QuantumOptics ket but keeps each trajectory pure: its `traceout!` samples a projection
onto the discarded subsystem's canonical basis, discards the outcome, and returns the
smaller conditional state. The ensemble of such trajectories reproduces the partial
trace.
"""
_traceout_state(state, i) = traceout!(state, i)

function traceout!(s::StateRef, i::Int)
    state = s.state[]
    newstate = _traceout_state(state, i)
    s.state[] = newstate
    removebackref!(s, i)
    s
end

"""
Delete one or more register slots.

`traceout!(reg, slot)` would reset (perform a partial trace) over the given subsystem.
The Hilbert space of the register gets automatically shrunk.

`traceout!(ref1, ref2, ...)` deletes several [`RegRef`](@ref)s in argument order
and returns the corresponding registers as a tuple. When the arguments include
every live slot backed by the same `StateRef`, that state is deleted as
one group without calling the backend's partial-trace implementation. Incomplete
groups are reduced one slot at a time.

For `QuantumMCRepr` trajectories, partial reduction samples the discarded
subsystem in its native canonical basis. Use [`project_traceout!`](@ref) instead
when the sampled outcome is needed.
"""
function traceout!(r::Register, i::Int)
    stateref = r.staterefs[i]
    if !isnothing(stateref)
        if nsubsystems(stateref)>1
            traceout!(stateref, r.stateindices[i])
        else
            r.staterefs[i] = nothing
            r.stateindices[i] = 0
        end
    end
    r
end
traceout!(r::RegRef) = traceout!(r.reg, r.idx)

_slot_identity(r::Register, i::Int) = (objectid(r.staterefs), i)

function traceout!(refs::RegRef...)
    materialized = RegRef[refs...]
    requested_slots = Set{Tuple{UInt,Int}}()
    candidate_states = IdDict{Base.RefValue{Any},StateRef}()
    sizehint!(requested_slots, length(materialized))
    sizehint!(candidate_states, length(materialized))

    for ref in materialized
        push!(requested_slots, _slot_identity(ref.reg, ref.idx))
        stateref = ref.reg.staterefs[ref.idx]
        if !isnothing(stateref) && nsubsystems(stateref) > 1
            get!(candidate_states, stateref.state, stateref)
        end
    end

    for stateref in values(candidate_states)
        all_requested = all(
            isnothing(reg) || _slot_identity(reg, index) in requested_slots
            for (reg, index) in zip(stateref.registers, stateref.registerindices)
        )
        if all_requested
            for stateindex in lastindex(stateref.registers):-1:firstindex(stateref.registers)
                isnothing(stateref.registers[stateindex]) && continue
                removebackref!(stateref, stateindex)
            end
        end
    end

    Tuple(map(materialized) do ref
        isnothing(ref.reg.staterefs[ref.idx]) ? ref.reg : traceout!(ref)
    end)
end

"""
    project_traceout!(ref::RegRef, basis; time = nothing)
    project_traceout!(reg::Register, i::Int, basis; time = nothing)
    project_traceout!(ref::RegRef, basis, values; time = nothing)
    project_traceout!(reg::Register, i::Int, basis, values; time = nothing)

Perform a projective measurement on the given slot of the given register.

An explicit tuple or vector of orthonormal basis states returns its one-based
basis index. Passing a second tuple or vector, `values`, returns `values[index]`
instead.

A symbolic operator like Pauli operators `X`, `Y`, and `Z` return their eigenvalues, e.g. `1` or `-1`.

`HomodyneMeasurement(θ)`, where `θ` is in radians, returns the real measured
quadrature `qθ = x*cos(θ) + p*sin(θ)`.

Every successful call removes the measured subsystem and its back-reference.
Clifford qubit measurements support the symbolic `X`, `Y`, and `Z` bases;
explicit basis vectors are supported by QuantumOptics and QuantumMC.
"""
function project_traceout! end

_preflight_project_traceout(state, i::Int, basis) = nothing

function _validate_project_traceout_values(basis, values)
    length(basis) == length(values) || throw(DimensionMismatch(
        "Measurement basis and outcome values must have the same length."
    ))
end

function project_traceout!(
    state,
    i::Int,
    basis::Union{Tuple,AbstractVector},
    values::Union{Tuple,AbstractVector},
)
    _validate_project_traceout_values(basis, values)
    outcome, state = project_traceout!(state, i, basis)
    values[outcome], state
end

function project_traceout!(reg::Register, i::Int, basis; time=nothing)
    project_traceout!(identity, reg, i, basis; time=time)
end
project_traceout!(r::RegRef, basis; time=nothing) = project_traceout!(r.reg, r.idx, basis; time)

function project_traceout!(
    reg::Register,
    i::Int,
    basis::Union{Tuple,AbstractVector},
    values::Union{Tuple,AbstractVector};
    time=nothing,
)
    _validate_project_traceout_values(basis, values)
    project_traceout!(outcome -> values[outcome], reg, i, basis; time)
end
function project_traceout!(
    r::RegRef,
    basis::Union{Tuple,AbstractVector},
    values::Union{Tuple,AbstractVector};
    time=nothing,
)
    project_traceout!(r.reg, r.idx, basis, values; time)
end

function project_traceout!(f, reg::Register, i::Int, basis; time=nothing)
    stateref = reg.staterefs[i]
    isnothing(stateref) && throw(ArgumentError(
        "Cannot project and trace out an unassigned register slot."
    ))
    stateindex = reg.stateindices[i]
    _preflight_project_traceout(stateref.state[], stateindex, basis)
    !isnothing(time) && uptotime!([reg], [i], time)
    j, stateref.state[] = project_traceout!(stateref.state[],stateindex,basis)
    removebackref!(stateref, stateindex)
    f(j)
end
project_traceout!(f, r::RegRef, basis; time=nothing) = project_traceout!(f, r.reg, r.idx, basis; time)
