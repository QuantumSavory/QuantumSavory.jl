export uptotime!, overwritetime!

"""
Evolve all the states in a register to a given time, according to the various backgrounds that they might have.

```jldoctest
julia> reg = Register(2, T1Decay(1.0))
Register with 2 slots: [ Qubit | Qubit ]
  Slots:
    nothing
    nothing

julia> initialize!(reg[1], X₁)
       observable(reg[1], σᶻ)
0.0 + 0.0im

julia> uptotime!(reg[1], 10)
       observable(reg[1], Z)
0.9999546000702374 + 0.0im
```
"""
function uptotime! end

function uptotime!(stateref::StateRef, idx::Int, background, Δt) # TODO this should be just for
    stateref.state[] = uptotime!(stateref.state[], idx, background, Δt)
end

function uptotime!(state, indices::Base.AbstractVecOrTuple{Int}, backgrounds, Δt) # TODO what about multiqubit correlated backgrounds... e.g. an interaction hamiltonian!?
    for (i,b) in zip(indices, backgrounds)
        isnothing(b) && continue
        uptotime!(state,i,b,Δt)
    end
end

function uptotime!(registers, indices::Base.AbstractVecOrTuple{Int}, now)
    staterecords = [(state=r.staterefs[i], idx=r.stateindices[i], bg=r.backgrounds[i], t=r.accesstimes[i])
                    for (r,i) in zip(registers, indices)
                    if isassigned(r,i)]
    for stategroup in groupby(x->x.state, staterecords) # TODO check this is grouping by ===... Actually, make sure that == for StateRef is the same as ===
        state = stategroup[1].state
        timegroups = sort!(collect(groupby(x->x.t, stategroup)), by=x->x[1].t)
        times = [[g[1].t for g in timegroups]; now]
        Δtimes = diff(times)
        for (i,Δt) in enumerate(Δtimes)
            Δt==0 && continue
            group = vcat(timegroups[1:i]...)
            stateindices = [g.idx for g in group]
            backgrounds = [g.bg for g in group]
            uptotime!(state, stateindices, backgrounds, Δt)
        end
    end
    for (i,r) in zip(indices, registers)
        if r.accesstimes[i] > now
            error("The simulation was commanded to apply an operation at time t=$(now) although the current simulation time is higher at t=$(r.accesstimes[i]) on register\n$(r)\nThis usually means multiple conflicting operations were attempted on the same register. Consider using locks around the offending operations.")
        end
        r.accesstimes[i] = now
    end
end
uptotime!(refs::Base.AbstractVecOrTuple{RegRef}, now) = uptotime!(map(r->r.reg, refs), map(r->r.idx, refs), now)
uptotime!(ref::RegRef, now) = uptotime!([ref.reg], [ref.idx], now)

function overwritetime!(registers, indices, now)
    for (i,r) in zip(indices, registers)
        r.accesstimes[i] = now
    end
    now
end
overwritetime!(refs::Base.AbstractVecOrTuple{RegRef}, now) = overwritetime!(map(r->r.reg, refs), map(r->r.idx, refs), now)
