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

"""The human-readable name or the simulated object as a string (potentially empty)."""
function name end
name(r::Register) = isnothing(r.netparent[]) ? "" : get(r.netparent[].names, r.netindex[], "")
name(r::RegisterNet) = isnothing(r.name) ? "" : r.name
name(::Nothing) = ""

function Base.show(io::IO, m::MIME"text/html", r::RegRef)
    print(io,"""
    <div class="quantumsavory_show quantumsavory_regref">
    """)
    isnothing(r.reg.netparent[]) || print(io,"""
    <span class"quantumsavory_regref_netname">$(name(r.reg.netparent[]))</span>
    <span class"quantumsavory_regref_regindex">$(r.reg.netindex[])</span>
    <span class"quantumsavory_regref_name">$(name(r.reg))</span>
    """)
    print(io,"""
    <span class"quantumsavory_regref_slotindex">$(r.idx)</span>
    </div>
    """)
end

function Base.show(io::IO, m::MIME"text/html", s::StateRef)
    print(io,"""
    <div class="quantumsavory_show quantumsavory_stateref">
    <div class="quantumsavory_stateref_regrefs">
    <ol>
    """)
    for rr in slots(s)
        print(io, "<li>")
        show(io, m, rr)
        print(io, "</li>")
    end
    print(io,"""
    </ol>
    </div>
    <div class="quantumsavory_stateref_state">
    """)
    stateshow(io, m, quantumstate(s), s)
    print(io,"""
    </div>
    </div>
    """)
end

"""Similar to `show(io, ::MIME"", ...)`, but private to avoid piracy."""
function stateshow(io, ::MIME"text/html", state, stateref)
    print(io,
    """
    <div class="quantumsavory_show quantumsavory_numericalstate quantumsavory_numericalstate_unknown">
    state of type <pre class="quantumsavory_typename quantumsavory_numericalstate_typename">$(typeof(state))</pre> does not support rich visualization in HTML
    </div>
    """)
end
