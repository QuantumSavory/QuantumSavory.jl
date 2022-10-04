module QuantumSavory

export Qubit, Qumode,
    QuantumOpticsRepr, QuantumMCRepr, CliffordRepr,
    UseAsState, UseAsOperation, UseAsObservable,
    StateRef, RegRef, Register, RegisterNet,
    newstate, initialize!,
    nsubsystems,
    swap!,
    registernetplot, registernetplot_axis, resourceplot_axis,
    @simlog, isfree, nongreedymultilock, spinlock,
    express, stab_to_ket

#TODO you can not assume you can always in-place modify a state. Have all these functions work on stateref, not stateref[]
# basically all ::QuantumOptics... should be turned into ::Ref{...}... but an abstract ref

using IterTools
using LinearAlgebra
using Graphs
#using Infiltrator

abstract type QuantumStateTrait end
abstract type AbstractRepresentation end
abstract type AbstractUse end
abstract type AbstractBackground end

"""Specifies that a given register slot contains qubits."""
struct Qubit <: QuantumStateTrait end
"""Specifies that a given register slot contains qumodes."""
struct Qumode <: QuantumStateTrait end

"""Representation using kets, densinty matrices, and superoperators governed by `QuantumOptics.jl`."""
struct QuantumOpticsRepr <: AbstractRepresentation end
"""Similar to `QuantumOpticsRepr`, but using trajectories instead of superoperators."""
struct QuantumMCRepr <: AbstractRepresentation end
"""Representation using tableaux governed by `QuantumClifford.jl`"""
struct CliffordRepr <: AbstractRepresentation end

struct UseAsState <: AbstractUse end
struct UseAsOperation <: AbstractUse end
struct UseAsObservable <: AbstractUse end

include("symbolics.jl")

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
    traits::Vector{Any}
    reprs::Vector{Any}
    backgrounds::Vector{Any}
    staterefs::Vector{Union{Nothing,StateRef}}
    stateindices::Vector{Int}
    accesstimes::Vector{Float64} # TODO do not hardcode the type
end
Register(traits,reprs,bg,sr,si) = Register(traits,reprs,bg,sr,si,fill(0.0,length(traits)))
Register(traits,reprs,bg) = Register(traits,reprs,bg,fill(nothing,length(traits)),fill(0,length(traits)),fill(0.0,length(traits)))
Register(traits,bg::Vector{<:AbstractBackground}) = Register(traits,default_repr.(traits),bg,fill(nothing,length(traits)),fill(0,length(traits)),fill(0.0,length(traits)))
Register(traits,reprs::Vector{<:AbstractRepresentation}) = Register(traits,reprs,fill(nothing,length(traits)),fill(nothing,length(traits)),fill(0,length(traits)),fill(0.0,length(traits)))
Register(traits) = Register(traits,default_repr.(traits),fill(nothing,length(traits)),fill(nothing,length(traits)),fill(0,length(traits)),fill(0.0,length(traits)))

struct RegRef
    reg::Register
    idx::Int
end

##

struct RegisterNet
    graph::SimpleGraph{Int64}
    registers::Vector{Register}
    vertex_metadata::Vector{Dict{Symbol,Any}}
    edge_metadata::Dict{Tuple{Int,Int},Dict{Symbol,Any}}
end
function RegisterNet(graph::SimpleGraph, registers::Vector{Register})
    @assert size(graph, 1) == length(registers)
    RegisterNet(graph, registers, [Dict{Symbol,Any}() for _ in registers], Dict{Tuple{Int,Int},Dict{Symbol,Any}}())
end
function RegisterNet(registers::Vector{Register})
    graph = grid([length(registers)])
    RegisterNet(graph, registers)
end

function add_register!(net::RegisterNet, r::Register)
    add_vertex!(net.graph)
    push!(net.registers, r)
    return length(Graph())
end

Graphs.add_vertex!(net::RegisterNet, a, b) = add_vertex!(net.graph, a, b)
Graphs.vertices(net::RegisterNet) = vertices(net.graph)
Graphs.edges(net::RegisterNet) = edges(net.graph)
Graphs.adjacency_matrix(net::RegisterNet) = adjacency_matrix(net.graph)

Base.getindex(net::RegisterNet, i::Int) = net.registers[i]
Base.getindex(net::RegisterNet, i::Int, j::Int) = net.registers[i][j]
Base.getindex(net::RegisterNet, i::Int, k::Symbol) = net.vertex_metadata[i][k]
Base.setindex!(net::RegisterNet, val, i::Int, k::Symbol) = begin net.vertex_metadata[i][k] = val end
Base.getindex(net::RegisterNet, i::Int, j::Int, k::Symbol) = net.edge_metadata[minmax(i,j)][k]
Base.setindex!(net::RegisterNet, val, i::Int, j::Int, k::Symbol) = begin net.edge_metadata[minmax(i,j)][k] = val end

##

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
    print(io, "Slot $(r.idx)/$(length(r.reg.traits)) of Register $(objectid(r.reg))") # TODO make this length call prettier
    print(io, "\nContent:")
    i,s = r.reg.stateindices[r.idx], r.reg.staterefs[r.idx]
    if isnothing(s)
        print(io, "\n    nothing")
    else
        print(io, "\n    $(i) @ $(typeof(s.state[]).name.module).$(typeof(s.state[]).name.name) $(objectid(s.state[]))")
    end
end

Base.getindex(r::Register, i::Int) = RegRef(r,i)

#Base.:(==)(r1::Register, r2::Register) =

function Base.isassigned(r::Register,i::Int) # TODO erase
    r.stateindices[i] != 0 # TODO this also usually means r.staterenfs[i] !== nothing - choose one and make things consistent
end
Base.isassigned(r::RegRef) = isassigned(r.reg, r.idx)

nsubsystems(s::StateRef) = length(s.registers) # nsubsystems(s.state[]) TODO this had to change because of references to "padded" states, but we probably still want to track more detailed information (e.g. how much have we overpadded)
nsubsystems_padded(s::StateRef) = nsubsystems(s.state[])
nsubsystems(r::Register) = length(r.staterefs)
nsubsystems(r::RegRef) = 1

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

include("baseops/subsystemcompose.jl")
include("baseops/initialize.jl")
include("baseops/traceout.jl")
include("baseops/apply.jl")
include("baseops/uptotime.jl")
include("baseops/observable.jl")

include("representations.jl")
include("backgrounds.jl")
include("noninstant.jl")

include("backends/quantumoptics/quantumoptics.jl")
include("backends/clifford/clifford.jl")

include("simjulia.jl")
include("makie.jl")

include("precompile.jl")

end # module
