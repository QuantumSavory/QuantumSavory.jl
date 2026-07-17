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

function traceout!(s::StateRef, i::Int)
    state = s.state[]
    newstate = traceout!(state, i)
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
Perform a projective measurement on the given slot of the given register.

`project_traceout!(reg, slot, [stateA, stateB])` performs a projective measurement,
projecting on either `stateA` or `stateB`, returning the index of the subspace
on which the projection happened. It assumes the list of possible states forms a basis
for the Hilbert space. The Hilbert space of the register is automatically shrunk.

A basis object can be specified on its own as well, e.g.
`project_traceout!(reg, slot, basis)`.
"""
function project_traceout! end

function project_traceout!(reg::Register, i::Int, basis; time=nothing)
    project_traceout!(identity, reg, i, basis; time=time)
end
project_traceout!(r::RegRef, basis; time=nothing) = project_traceout!(r.reg, r.idx, basis; time)

function project_traceout!(f, reg::Register, i::Int, basis; time=nothing)
    !isnothing(time) && uptotime!([reg], [i], time)
    stateref = reg.staterefs[i]
    stateindex = reg.stateindices[i]
    if isnothing(stateref) # TODO maybe use isassigned
        throw("error") # make it more descriptive
    end
    j, stateref.state[] = project_traceout!(stateref.state[],stateindex,basis)
    removebackref!(stateref, stateindex)
    f(j)
end
project_traceout!(f, r::RegRef, basis; time=nothing) = project_traceout!(f, r.reg, r.idx, basis; time)
