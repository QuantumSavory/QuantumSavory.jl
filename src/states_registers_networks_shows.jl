function Base.show(io::IO, s::StateRef)
    print(io, "State containing $(nsubsystems(s.state[])) subsystems in $(typeof(s.state[]).name.module) implementation")
    print(io, "\n  In registers:")
    for (i,r) in zip(s.registerindices, s.registers)
        if isnothing(r)
            print(io, "\n    not used")
        else
            print(io, "\n    $(i)@$(objectid(r))")
        end
    end
end

function Base.show(io::IO, r::Register)
    print(io, "Register with $(length(r.traits)) slots") # TODO make this length call prettier
    print(io, ": [ ")
    print(io, join(string.(typeof.(r.traits)), " | "))
    print(io, " ]")
    print(io, "\n  Slots:")
    for (i,s) in zip(r.stateindices, r.staterefs)
        if isnothing(s)
            print(io, "\n    nothing")
        else
            print(io, "\n    Subsystem $(i) of $(typeof(s.state[]).name.module).$(typeof(s.state[]).name.name) $(objectid(s.state[]))")
        end
    end
end

function Base.show(io::IO, net::RegisterNet)
    print(io, "A network of $(length(net.registers)) registers in a graph of $(length(edges(net.graph))) edges\n")
end

function Base.show(io::IO, r::RegRef)
    if get(io, :compact, false) | haskey(io, :typeinfo)
        print(io, "Slot $(r.idx)")
    else
        print(io, "Slot $(r.idx)/$(length(r.reg.traits)) of Register $(objectid(r.reg))") # TODO make this length call prettier
        print(io, "\nContent:")
        i,s = r.reg.stateindices[r.idx], r.reg.staterefs[r.idx]
        if isnothing(s)
            print(io, "\n    nothing")
        else
            print(io, "\n    $(i) @ $(typeof(s.state[]).name.module).$(typeof(s.state[]).name.name) $(objectid(s.state[]))")
        end
    end
end
