import QuantumInterface: traceout!

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
Delete the given slot of the given register.

`traceout!(reg, slot)` would reset (perform a partial trace) over the given subsystem.
The Hilbert space of the register is automatically shrinked.
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

"""
Perform a projective measurement on the given slot of the given register.

`project_traceout!(reg, slot, [stateA, stateB])` performs a projective measurement,
projecting on either `stateA` or `stateB`, returning the index of the subspace
on which the projection happened. It assumes the list of possible states forms a basis
for the Hilbert space. The Hilbert space of the register is automatically shrinked.

A basis object can be specified on its own as well, e.g.
`project_traceout!(reg, slot, basis)`.
"""
function project_traceout! end

function project_traceout!(reg::Register, i::Int, psis; time=nothing)
    project_traceout!(identity, reg, i, psis; time=time)
end
project_traceout!(r::RegRef, psis; time=nothing) = project_traceout!(r.reg, r.idx, psis; time=nothing)

function project_traceout!(f, reg::Register, i::Int, psis; time=nothing)
    !isnothing(time) && uptotime!([reg], [i], time)
    stateref = reg.staterefs[i]
    stateindex = reg.stateindices[i]
    if isnothing(stateref) # TODO maybe use isassigned
        throw("error") # make it more descriptive
    end
    j, stateref.state[] = project_traceout!(stateref.state[],stateindex,psis)
    removebackref!(stateref, stateindex)
    f(j)
end
project_traceout!(f, r::RegRef, psis; time=nothing) = project_traceout!(f, r.reg, r.idx, psis; time=nothing)
