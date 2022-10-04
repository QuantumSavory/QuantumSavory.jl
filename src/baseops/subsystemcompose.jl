export subsystemcompose

#subsystemcompose(s...) = reduce(subsystemcompose, s)


# TODO use a trait system to select the type of composition
# - do they need to be collapsed
# - do they have unused slots that can be refilled
# - are they just naively composed together
function subsystemcompose(regs::Vector{Register}, indices) # TODO add a type constraint on regs
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
