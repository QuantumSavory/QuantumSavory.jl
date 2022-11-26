module QuantumSavory

using Reexport

using IterTools
using LinearAlgebra
using Graphs

@reexport using QSymbolics
# also imported, because QuantumSavory code outside of QSymbolics needs them, e.g. for `express`
using QSymbolics:
    AbstractRepresentation, AbstractUse,
    CliffordRepr, QuantumOpticsRepr, QuantumMCRepr,
    basis, tensor, ⊗, Operator, Ket, SuperOperator, Basis, SpinBasis, # from QuantumOpticsBase
    metadata, istree, operation, arguments, Symbolic, # from Symbolics
    HGate, XGate, YGate, ZGate, CPHASEGate, CNOTGate,
    XBasisState, YBasisState, ZBasisState,
    STensorOperator, SScaledOperator, SAddOperator

export StateRef, RegRef, Register, RegisterNet
export Qubit, Qumode,
       QuantumOpticsRepr, QuantumMCRepr, CliffordRepr,
       UseAsState, UseAsObservable, UseAsOperation
#TODO you can not assume you can always in-place modify a state. Have all these functions work on stateref, not stateref[]
# basically all ::QuantumOptics... should be turned into ::Ref{...}... but an abstract ref

abstract type QuantumStateTrait end
abstract type AbstractBackground end

"""Specifies that a given register slot contains qubits."""
struct Qubit <: QuantumStateTrait end
"""Specifies that a given register slot contains qumodes."""
struct Qumode <: QuantumStateTrait end

# TODO move these definitions to a neater place
default_repr(::Qubit) = QuantumOpticsRepr()


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
Graphs.neighbors(net::RegisterNet, v) = neighbors(net.graph, v)
Graphs.adjacency_matrix(net::RegisterNet) = adjacency_matrix(net.graph)
Graphs.ne(net::RegisterNet) = ne(net.graph)
Graphs.nv(net::RegisterNet) = nv(net.graph)

# Get register
Base.getindex(net::RegisterNet, i::Int) = net.registers[i]
# Get register slot reference
Base.getindex(net::RegisterNet, i::Int, j::Int) = net.registers[i][j]
# Get and set vertex metadata
Base.getindex(net::RegisterNet, i::Int, k::Symbol) = net.vertex_metadata[i][k]
Base.setindex!(net::RegisterNet, val, i::Int, k::Symbol) = begin net.vertex_metadata[i][k] = val end
# Get and set edge metadata
Base.getindex(net::RegisterNet, ij::Tuple{Int,Int}, k::Symbol) = net.edge_metadata[minmax(ij...)][k]
function Base.setindex!(net::RegisterNet, val, ij::Tuple{Int,Int}, k::Symbol)
    edge = minmax(ij...)
    haskey(net.edge_metadata,edge) || (net.edge_metadata[edge] = Dict{Symbol,Any}())
    net.edge_metadata[edge][k] = val
end
Base.getindex(net::RegisterNet, ij::Graphs.SimpleEdge, k::Symbol) = net[(ij.src, ij.dst),k]
Base.setindex!(net::RegisterNet, val, ij::Graphs.SimpleEdge, k::Symbol) = begin net[(ij.src, ij.dst),k] = val end
# Get and set with colon notation
Base.getindex(net::RegisterNet, ::Colon) = net.registers
Base.getindex(net::RegisterNet, ::Colon, j::Int) = [r[j] for r in net.registers]
Base.getindex(net::RegisterNet, ::Colon, k::Symbol) = [m[k] for m in net.vertex_metadata]
Base.getindex(net::RegisterNet, ::Tuple{Colon,Colon}, k::Symbol) = [net.edge_metadata[minmax(ij)...][k] for ij in edges(net)]
function Base.setindex!(net::RegisterNet, v, ::Colon, k::Symbol)
    for m in net.vertex_metadata
        m[k] = v
    end
end
function Base.setindex!(net::RegisterNet, v, ::Tuple{Colon,Colon}, k::Symbol)
    for ij in edges(net)
        net[ij,k] = v
    end
end
function Base.setindex!(net::RegisterNet, @nospecialize(f::Function), ::Colon, k::Symbol)
    for m in net.vertex_metadata
        m[k] = f()
    end
end
function Base.setindex!(net::RegisterNet, @nospecialize(f::Function), ::Tuple{Colon,Colon}, k::Symbol)
    for ij in edges(net)
        net[ij,k] = f()
    end
end

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
