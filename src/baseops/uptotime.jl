export uptotime!, overwritetime!

function uptotime!(stateref::StateRef, idx::Int, background, Δt) # TODO this should be just for
    stateref.state[] = uptotime!(stateref.state[], idx, background, Δt)
end

function uptotime!(state, indices::AbstractVector, backgrounds, Δt) # TODO what about multiqubit correlated backgrounds... e.g. an interaction hamiltonian!?
    for (i,b) in zip(indices, backgrounds)
        isnothing(b) && continue
        uptotime!(state,i,b,Δt)
    end
end

function uptotime!(registers, indices, now)
    staterecords = [(state=r.staterefs[i], idx=r.stateindices[i], bg=r.backgrounds[i], t=r.accesstimes[i])
                    for (r,i) in zip(registers, indices)]
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
uptotime!(refs::Vector{RegRef}, now) = uptotime!([r.reg for r in refs], [r.idx for r in refs], now)
uptotime!(ref::RegRef, now) = uptotime!([ref.reg], [ref.idx], now)

function overwritetime!(registers, indices, now)
    for (i,r) in zip(indices, registers)
        r.accesstimes[i] = now
    end
    now
end
overwritetime!(refs::Vector{RegRef}, now) = overwritetime!([r.reg for r in refs], [r.idx for r in refs], now)
