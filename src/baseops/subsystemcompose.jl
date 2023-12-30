nsubsystems(s::StateRef) = length(s.registers) # nsubsystems(s.state[]) TODO this had to change because of references to "padded" states, but we probably still want to track more detailed information (e.g. how much have we overpadded)
nsubsystems_padded(s::StateRef) = nsubsystems(s.state[])
nsubsystems(r::Register) = length(r.staterefs)
nsubsystems(r::RegRef) = 1
nsubsystems(::Nothing) = 1 # TODO consider removing this and reworking the functions that depend on it. E.g., a reason to have it when performing a project_traceout measurement on a state that contains only one subsystem

function swap!(reg1::Register, reg2::Register, i1::Int, i2::Int; time=nothing)
    if reg1===reg2 && i1==i2
        return
    end
    if reg1.accesstimes[i1] != reg2.accesstimes[i2]
        maxtime = max(reg1.accesstimes[i1], reg2.accesstimes[i2])
        maxtime = isnothing(time) ? maxtime : max(maxtime, time)
        uptotime!(reg1[i1], maxtime)
        uptotime!(reg2[i2], maxtime)
    end
    state1, state2 = reg1.staterefs[i1], reg2.staterefs[i2]
    stateind1, stateind2 = reg1.stateindices[i1], reg2.stateindices[i2]
    reg1.staterefs[i1], reg2.staterefs[i2] = state2, state1
    reg1.stateindices[i1], reg2.stateindices[i2] = stateind2, stateind1
    if !isnothing(state1)
        state1.registers[stateind1] = reg2
        state1.registerindices[stateind1] = i2
    end
    if !isnothing(state2)
        state2.registers[stateind2] = reg1
        state2.registerindices[stateind2] = i1
    end
end
swap!(r1::RegRef, r2::RegRef; time=nothing) = swap!(r1.reg, r2.reg, r1.idx, r2.idx; time)

#subsystemcompose(s...) = reduce(subsystemcompose, s)


# TODO use a trait system to select the type of composition
# - do they need to be collapsed
# - do they have unused slots that can be refilled
# - are they just naively composed together
"""Ensure that the all slots of the given registers are represented by one single state object, i.e. that all the register slots are tracked in the same Hilbert space."""
function subsystemcompose(regs::Base.AbstractVecOrTuple{Register}, indices) # TODO add a type constraint on regs
    # Get all references to states that matter, removing duplicates
    staterefs = unique(objectid, [r.staterefs[i] for (r,i) in zip(regs,indices)]) # TODO do not use == checks like in `unique`, use ===
    # Prepare the larger state object
    newstate = subsystemcompose([s.state[] for s in staterefs]...)
    # Prepare the new state reference
    newregisters = vcat([s.registers for s in staterefs]...)
    newregisterindices = vcat([s.registerindices for s in staterefs]...)
    newref = StateRef(newstate, newregisters, newregisterindices)
    # Update all registers to point to the new state reference
    offsets = [0,cumsum(nsubsystems_padded.(staterefs))...]
    for (r,i) in zip(newregisters,newregisterindices)
        isnothing(r) && continue
        oldref = r.staterefs[i]
        r.staterefs[i] = newref
        offset = offsets[findfirst(ref->ref===oldref, staterefs)]
        r.stateindices[i] += offset
    end
    newref
end
subsystemcompose(refs::RegRef...) = subsystemcompose([r.reg for r in refs], [r.idx for r in refs]) # TODO temporary arrays are allocated here
