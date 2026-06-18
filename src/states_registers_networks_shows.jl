"""The human-readable name or the simulated object as a string or `nothing`."""
function name end
name(r::Register) = isnothing(r.netparent[]) ? nothing : get(r.netparent[].names, r.netindex[], nothing)
name(r::RegisterNet) = r.name
name(::Nothing) = nothing
"""The human-readable name or the simulated object as a string (potentially empty)."""
function namestr(n)
    return isnothing(name(n)) ? "" : name(n)
end
function namestr(reg::Register; useobjectid=true)
    net = parent(reg)
    if isnothing(net)
        useobjectid ? "$(objectid(reg))" : ""
    else
        regname = name(reg)
        if isnothing(regname)
            netname = name(net)
            if isnothing(netname)
                "$(parentindex(reg))"
            else
                "$netname[$(parentindex(reg))]"
            end
        else
            "$regname(#$(parentindex(reg)))"
        end
    end
end

function Base.show(io::IO, s::StateRef)
    if get(io, :compact, false) | haskey(io, :typeinfo)
        print(io, "State $(nameof(typeof(s.state[]))) of size $(nsubsystems(s.state[]))")
    else
        print(io, "State containing $(nsubsystems(s.state[])) subsystems in $(typeof(s.state[]).name.module) implementation")
        print(io, "\n  In registers:")
        for (i,r) in zip(s.registerindices, s.registers)
            if isnothing(r)
                print(io, "\n    not used")
            else
                print(IOContext(io, :compact => true), "\n    ",(r[i]))
            end
        end
    end
end

function Base.show(io::IO, r::Register)
    regname = namestr(r; useobjectid=false)
    if get(io, :compact, false) | haskey(io, :typeinfo)
        print(io, "Register $(regname)")
    else
        print(io, "Register $(regname) with $(length(r.traits)) slots") # TODO make this length call prettier
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
end

function Base.show(io::IO, net::RegisterNet)
    print(io, "A network of $(length(net.registers)) registers in a graph of $(length(edges(net.graph))) edges\n")
end

function Base.show(io::IO, r::RegRef)
    regstr = namestr(parent(r))
    if get(io, :compact, false) | haskey(io, :typeinfo)
        print(io, "$(regstr).$(r.idx)")
    else
        print(io, "Slot $(r.idx)/$(length(r.reg.traits)) of Register $(regstr)") # TODO make this length call prettier
        print(io, "\nContent:")
        i,s = r.reg.stateindices[r.idx], r.reg.staterefs[r.idx]
        if isnothing(s)
            print(io, "\n    nothing")
        else
            print(io, "\n    $(i) @ ")
            print(IOContext(io, :compact => true), s)
        end
    end
end
