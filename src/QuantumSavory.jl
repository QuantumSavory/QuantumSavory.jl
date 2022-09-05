module QuantumSavory

export QubitTrait, QumodeTrait, Layout, Connectivity,
    StateRef, Register, newstate, initialize!,
    nsubsystems,
    subsystemcompose, traceout!, project_traceout!,
    uptotime!, overwritetime!, T1Decay, T2Dephasing, krausops,
    removebackref!, swap!, apply!,
    observable,
    registersgraph, RGHandler, registersgraph_axis, resourceplot_axis,
    @simlog, isfree, nongreedymultilock, spinlock,
    X,Y,Z,H,CNOT,CPHASE,X1,X2,Y1,Y2,Z1,Z2,SProjector,MixedState

#TODO you can not assume you can always in-place modify a state. Have all these functions work on stateref, not stateref[]
# basically all ::QuantumOptics... should be turned into ::Ref{...}... but an abstract ref

using Distributions
using IterTools
using LinearAlgebra
#using Infiltrator

include("symbolics.jl")

abstract type QuantumStateTrait end
"""Specifies that a given register slot contains qubits."""
struct QubitTrait <: QuantumStateTrait end
"""Specifies that a given register slot contains qumodes."""
struct QumodeTrait <: QuantumStateTrait end

abstract type AbstractLayout end
abstract type AbstractConnectivity end

struct Layout <: AbstractLayout
    traits::Vector{QuantumStateTrait}
    metadata # TODO from here you can grab available lifetimes or other parameters
end

Layout(traits) = Layout(traits, nothing)

# TODO better constructors
# TODO am I overusing Ref
struct StateRef
    state::Base.RefValue{Any} # TODO it would be nice if this was not abstract but `uptotime!` converts between types... maybe make StateRef{T} state::RefValue{T} and a new function that swaps away the backpointers in the appropriate registers
    registers::Vector{Any} # TODO Should be Vector{Register}, but right now we occasionally set it to nothing to deal with padded storage
    registerindices::Vector{Int}
    StateRef(state::Base.RefValue{S}, registers, registerindices) where {S} = new(state, registers, registerindices)
end

StateRef(state, registers, registerindices) = StateRef(Ref{Any}(copy(state)), registers, registerindices) # TODO same as above, this should not be forced to Any

"""
The main data structure in `QuantumSavory`, used to represent a quantum register in an arbitrary formalism.
"""
struct Register # TODO better type description
    layout::AbstractLayout
    staterefs::Vector{Union{Nothing,StateRef}}
    stateindices::Vector{Int}
    accesstimes::Vector{Float64} # TODO do not hardcode the type
    backgrounds::Vector{Any}
    name::Symbol
end
Register(l,sr,si,bg) = Register(l,sr,si,fill(0.0,length(l.traits)),bg,gensym())
Register(l,sr,si) = Register(l,sr,si,fill(nothing,length(l.traits)))

Register(l,sr,si,bg,s::Symbol) = Register(l,sr,si,fill(0.0,length(l.traits)),bg,s)
Register(l,sr,si,s::Symbol) = Register(l,sr,si,fill(nothing,length(l.traits)),s)
Register(l,bg,s::Symbol) = Register(l,fill(nothing,length(l.traits)),fill(0,length(l.traits)),fill(0.0,length(l.traits)),bg,s)
Register(l,s::Symbol) = Register(l,fill(nothing,length(l.traits)),s) # TODO traits should be an interface
Register(l) = Register(l,gensym())

struct RegRef
    reg::Register
    idx::Int
end

function Base.show(io::IO, s::StateRef)
    print(io, "State containing $(nsubsystems(s.state[])) subsystems in $(typeof(s.state[]).name.module) implementation")
    print(io, "\n  In registers:")
    for (i,r) in zip(s.registerindices, s.registers)
        if isnothing(r)
            print(io, "\n    not used")
        else
            print(io, "\n    $(i)@$(r.name)")
        end
    end
end

function Base.show(io::IO, r::Register)
    print(io, "Register $(r.name) of $(length(r.layout.traits)) slots") # TODO make this length call prettier
    print(io, "\n  ")
    show(io, r.layout)
    print(io, "\n  Slots:")
    for (i,s) in zip(r.stateindices, r.staterefs)
        if isnothing(s)
            print(io, "\n    nothing")
        else
            print(io, "\n    $(i) @ $(typeof(s.state[]).name.module).$(typeof(s.state[]).name.name) $(objectid(s.state[]))")
        end
    end
end

function Base.show(io::IO, r::RegRef)
    print(io, "Slot $(r.idx)/$(length(r.layout.traits)) of Register $(r.reg.name)") # TODO make this length call prettier
    print(io, "\nContent:")
    i,s = r.reg.stateindices[r.idx], r.reg.staterefs[r.idx]
    if isnothing(s)
        print(io, "\n    nothing")
    else
        print(io, "\n    $(i) @ $(typeof(s.state[]).name.module).$(typeof(s.state[]).name.name) $(objectid(s.state[]))")
    end
end

Base.getindex(r::Register, i::Int) = RegRef(r,i)

Base.:(==)(r1::Register, r2::Register) = r1.name == r2.name

function Base.isassigned(r::Register,i::Int) # TODO erase
    r.stateindices[i] != 0 # TODO this also usually means r.staterenfs[i] !== nothing - choose one and make things consistent
end
Base.isassigned(r::RegRef) = isassigned(r.reg, r.idx)

function initialize!(reg::Register,i::Int; time=nothing)
    s = newstate(reg.layout.traits[i]) # TODO this should be an interface
    initialize!(reg,i,s; time=time)
end
initialize!(r::RegRef; time=nothing) = initialize!(r.reg, r.idx; time)

"""
Set the state of a given set of registers.

`initialize!([regA,regB], [slot1,slot2], state)` would
set the state of the given slots in the given registers to `state`.
`state` can be any supported state representation,
e.g., kets or density matrices from `QuantumOptics.jl`
or tableaux from `QuantumClifford.jl`.
"""
function initialize!(regs::Vector{Register},indices::Vector{Int},state; time=nothing)
    stateref = StateRef(state, collect(regs), collect(indices))
    for (si,(reg,ri)) in enumerate(zip(regs,indices))
        if isassigned(reg,ri) # TODO decide if this is an error or a warning or nothing
            throw("error") # TODO be more descriptive
        end
        reg.staterefs[ri] = stateref
        reg.stateindices[ri] = si
        !isnothing(time) && (reg.accesstimes[ri] = time)
    end
    stateref
end
initialize!(refs::Vector{RegRef}, state; time=nothing) = initialize!([r.reg for r in refs], [r.idx for r in refs], state; time)
initialize!(refs::NTuple{N,RegRef}, state; time=nothing) where {N} = initialize!([r.reg for r in refs], [r.idx for r in refs], state; time) # TODO temporary array allocated here
initialize!(reg::Register,i::Int,state; time=nothing) = initialize!([reg],[i],state; time)
initialize!(r::RegRef, state; time=nothing) = initialize!(r.reg, r.idx, state; time)
initialize!(r::Vector{Register},i::Vector{Int},state::Symbolic; time=nothing) = initialize!(r,i,express(r,i,state); time)


nsubsystems(s::StateRef) = length(s.registers) # nsubsystems(s.state[]) TODO this had to change because of references to "padded" states, but we probably still want to track more detailed information (e.g. how much have we overpadded)
nsubsystems_padded(s::StateRef) = nsubsystems(s.state[])
nsubsystems(r::Register) = length(r.staterefs)
nsubsystems(r::RegRef) = 1

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

function swap!(reg1::Register, reg2::Register, i1::Int, i2::Int)
    if reg1===reg2 && i1==i2
        return
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
swap!(r1::RegRef, r2::RegRef) = swap!(r1.reg, r2.reg, r1.idx, r2.idx)

"""
Calculate the expectation value of a quantum observable on the given register and slot.

`observable([regA, regB], [slot1, slot2], obs)` would calculate the expectation value
of the `obs` observable (using the appropriate formalism, depending on the state
representation in the given registers).
"""
function observable(regs::Vector{Register}, indices::Vector{Int}, obs, something=nothing; time=nothing) # TODO weird split between positional and keyword arguments
    staterefs = [r.staterefs[i] for (r,i) in zip(regs, indices)]
    # TODO it should still work even if they are not represented in the same state
    (any(isnothing, staterefs) || !all(s->s===staterefs[1], staterefs)) && return something
    !isnothing(time) && uptotime!(regs, indices, time)
    state = staterefs[1].state[]
    state_indices = [r.stateindices[i] for (r,i) in zip(regs, indices)]
    observable(state, state_indices, obs)
end
observable(refs::Vector{RegRef}, obs, something=nothing; time=nothing) = observable([r.reg for r in refs], [r.idx for r in refs], obs, something; time)
observable(refs::NTuple{N,RegRef}, obs, something=nothing; time=nothing) where {N} = observable((r.reg for r in refs), (r.idx for r in refs), obs, something; time)
observable(r::Vector{Register},i::Vector{Int},obs::Symbolic, something=nothing; time=nothing) = observable(r,i,express(r,i,obs), something; time)


"""
Apply a given operation on the given set of register slots.

`apply!([regA, regB], [slot1, slot2], Gates.CNOT)` would apply a CNOT gate
on the content of the given registers at the given slots.
The appropriate representatin of the gate is used,
depending on the formalism under which a quantum state is stored in the given registers.
The Hilbert spaces of the registers are automatically joined if necessary.
"""
function apply!(regs, indices, operation; time=nothing) # TODO add a type constraint on regs
    !isnothing(time) && uptotime!(regs, indices, time)
    subsystemcompose(regs,indices)
    state = regs[1].staterefs[indices[1]].state[]
    state_indices = [r.stateindices[i] for (r,i) in zip(regs, indices)]
    state = apply!(state, state_indices, operation)
    regs[1].staterefs[indices[1]].state[] = state
    regs
end
apply!(refs::Vector{RegRef}, operation; time=nothing) = apply!([r.reg for r in refs], [r.idx for r in refs], operation; time=nothing)
apply!(refs::NTuple{N,RegRef}, operation; time=nothing) where {N} = apply!([r.reg for r in refs], [r.idx for r in refs], operation; time=nothing) # TODO temporary array allocated here
apply!(ref::RegRef, operation; time=nothing) = apply!([ref.reg], [ref.idx], operation; time=nothing)

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
        r.accesstimes[i] = now
    end
end
uptotime!(refs::Vector{RegRef}, now) = uptotime!([r.reg for r in refs], [r.idx for r in refs], now)

function overwritetime!(registers, indices, now)
    for (i,r) in zip(indices, registers)
        r.accesstimes[i] = now
    end
end
overwritetime!(refs::Vector{RegRef}, now) = overwritetime!([r.reg for r in refs], [r.idx for r in refs], now)

# TODO make a library of backgrounds, traits about whether they are unitary or not, etc, and helper interfaces

"""A background describing the T₁ decay of a two-level system."""
struct T1Decay
    t1
end

"""A background describing the T₂ dephasing of a two-level system."""
struct T2Dephasing
    t2
end

include("qo_extras.jl")
include("qc_extras.jl")
include("sj_extras.jl")
include("makie.jl")

function newstate(::QumodeTrait)
    b = FockBasis(5)
    basisstate(b,1)
end

function newstate(::QubitTrait)
    b = SpinBasis(1//2)
    spinup(b) # logical 0
end

end # module
