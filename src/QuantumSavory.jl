module QuantumSavory

using Reexport

using IterTools
using LinearAlgebra
using Graphs

using QuantumInterface: basis, tensor, ⊗, apply!, traceout!,
    AbstractOperator, AbstractKet, AbstractSuperOperator, Basis, SpinBasis
import QuantumInterface: nsubsystems

export apply!, traceout!, removebackref!
export project_traceout! #TODO should move to QuantumInterface

import ConcurrentSim
using ResumableFunctions

@reexport using QuantumSymbolics
using QuantumSymbolics:
    AbstractRepresentation, AbstractUse,
    CliffordRepr, QuantumOpticsRepr, QuantumMCRepr,
    metadata, istree, operation, arguments, Symbolic, # from Symbolics
    HGate, XGate, YGate, ZGate, CPHASEGate, CNOTGate,
    XBasisState, YBasisState, ZBasisState,
    STensorOperator, SScaledOperator, SAddOperator

export StateRef, RegRef, Register, RegisterNet
export Qubit, Qumode, QuantumStateTrait,
    CliffordRepr, QuantumOpticsRepr, QuantumMCRepr,
    UseAsState, UseAsObservable, UseAsOperation,
    AbstractBackground
export QuantumChannel


#TODO you can not assume you can always in-place modify a state. Have all these functions work on stateref, not stateref[]
# basically all ::QuantumOptics... should be turned into ::Ref{...}... but an abstract ref

"""An abstract type for the various types of states that can be given to [`Register`](@ref) slots, e.g. qubit, harmonic oscillator, etc."""
abstract type QuantumStateTrait end

"""An abstract type for the various background processes that might be inflicted upon a [`Register`](@ref) slot, e.g. decay, dephasing, etc."""
abstract type AbstractBackground end

"""Specifies that a given register slot contains qubits."""
struct Qubit <: QuantumStateTrait end
"""Specifies that a given register slot contains qumodes."""
struct Qumode <: QuantumStateTrait end

# TODO move these definitions to a neater place
default_repr(::Qubit) = QuantumOpticsRepr()
default_repr(::Qumode) = QuantumOpticsRepr()


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
mutable struct Register # TODO better type description
    traits::Vector{Any}
    reprs::Vector{Any}
    backgrounds::Vector{Any}
    staterefs::Vector{Union{Nothing,StateRef}}
    stateindices::Vector{Int}
    accesstimes::Vector{Float64} # TODO do not hardcode the type
    env::Any
    locks::Vector{Any}
end
Register(traits,reprs,bg,sr,si) = Register(traits,reprs,bg,sr,si,fill(0.0,length(traits)))
Register(traits,reprs,bg) = Register(traits,reprs,bg,fill(nothing,length(traits)),fill(0,length(traits)),fill(0.0,length(traits)))
Register(traits,bg::Base.AbstractVecOrTuple{<:Union{Nothing,<:AbstractBackground}}) = Register(traits,default_repr.(traits),bg,fill(nothing,length(traits)),fill(0,length(traits)),fill(0.0,length(traits)))
Register(traits,reprs::Base.AbstractVecOrTuple{<:AbstractRepresentation}) = Register(traits,reprs,fill(nothing,length(traits)),fill(nothing,length(traits)),fill(0,length(traits)),fill(0.0,length(traits)))
Register(traits) = Register(traits,default_repr.(traits),fill(nothing,length(traits)),fill(nothing,length(traits)),fill(0,length(traits)),fill(0.0,length(traits)))
Register(nqubits::Int) = Register([Qubit() for _ in 1:nqubits])
Register(nqubits::Int,repr::AbstractRepresentation) = Register(fill(Qubit(),nqubits),fill(repr,nqubits))
Register(nqubits::Int,bg::AbstractBackground) = Register(fill(Qubit(),nqubits),fill(bg,nqubits))
function Register(traits, reprs, bg, sr, si, at)
    env = ConcurrentSim.Simulation()
    Register(traits, reprs, bg, sr, si, at, env, [ConcurrentSim.Resource(env) for _ in traits])
end

"""
A reference to a [`Register`](@ref) slot, convenient for use with functions like [`apply!`](@ref), etc.

```jldoctest
julia> r = Register(2)
       initialize!(r[1], X₁)
       observable(r[1], X)
0.9999999999999998 + 0.0im
```
"""
struct RegRef
    reg::Register
    idx::Int
end

"""
A network of [`Register`](@ref)s with convenient graph API as well.
"""
struct RegisterNet
    graph::SimpleGraph{Int64}
    registers::Vector{Register}
    vertex_metadata::Vector{Dict{Symbol,Any}}
    edge_metadata::Dict{Tuple{Int,Int},Dict{Symbol,Any}}
    directed_edge_metadata::Dict{Pair{Int,Int},Dict{Symbol,Any}}
    function RegisterNet(graph, registers, vertex_metadata, edge_metadata, directed_edge_metadata)
        all_are_at_zero = all(iszero(ConcurrentSim.now(r.env)) && isempty(r.env.heap) && isnothing(r.env.active_proc) for r in registers)
        all_are_same = all(registers[1].env === r.env for r in registers)
        if !all_are_same
            if all_are_at_zero
                env = ConcurrentSim.Simulation()
                for r in registers
                    r.env = env
                    for i in eachindex(r.locks)
                        r.locks[i] = ConcurrentSim.Resource(env,1)
                    end
                end
            else
                error("When constructing a `RegisterNet`, the registers must either have not been used yet or have to already belong to the same simulation time tracker, which is not the case here. The simplest way to fix this error is to immediately construct the `RegisterNet` after you have constructed the registers.")
            end
        end
        new(graph, registers, vertex_metadata, edge_metadata, directed_edge_metadata)
    end
end
"""
Construct a [`RegisterNet`](@ref) from a given list of [`Register`](@ref)s and a graph.

```jldoctest
julia> graph = grid([2,2]) # from Graphs.jl
{4, 4} undirected simple Int64 graph

julia> registers = [Register(1), Register(2), Register(1), Register(2)]
4-element Vector{Register}:
 Register with 1 slots: [ Qubit ]
  Slots:
    nothing
 Register with 2 slots: [ Qubit | Qubit ]
  Slots:
    nothing
    nothing
 Register with 1 slots: [ Qubit ]
  Slots:
    nothing
 Register with 2 slots: [ Qubit | Qubit ]
  Slots:
    nothing
    nothing

julia> net = RegisterNet(graph, registers)
A network of 4 registers in a graph of 4 edges


julia> neighbors(net, 1) # from Graphs.jl
2-element Vector{Int64}:
 2
 3
```
"""
function RegisterNet(graph::SimpleGraph, registers::Vector{Register})
    @assert size(graph, 1) == length(registers)
    RegisterNet(graph, registers, [Dict{Symbol,Any}() for _ in registers], Dict{Tuple{Int,Int},Dict{Symbol,Any}}(), Dict{Pair{Int,Int},Dict{Symbol,Any}}())
end
"""Construct a [`RegisterNet`](@ref) from a given list of [`Register`](@ref)s, defaulting to a chain topology.

```jldoctest
julia> net = RegisterNet([Register(2), Register(4), Register(2)])
A network of 3 registers in a graph of 2 edges

julia> neighbors(net,2) # from Graphs.jl
2-element Vector{Int64}:
 1
 3
```
"""
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
# Get and set directed edge metadata
Base.getindex(net::RegisterNet, ij::Pair{Int,Int}, k::Symbol) = net.directed_edge_metadata[ij][k]
function Base.setindex!(net::RegisterNet, val, ij::Pair{Int,Int}, k::Symbol)
    edge = ij
    haskey(net.directed_edge_metadata,edge) || (net.directed_edge_metadata[edge] = Dict{Symbol,Any}())
    net.directed_edge_metadata[edge][k] = val
end
Base.getindex(net::RegisterNet, ij::Graphs.SimpleEdge, k::Symbol) = net[(ij.src, ij.dst),k]
Base.setindex!(net::RegisterNet, val, ij::Graphs.SimpleEdge, k::Symbol) = begin net[(ij.src, ij.dst),k] = val end
# Get and set with colon notation
Base.getindex(net::RegisterNet, ::Colon) = net.registers
Base.getindex(net::RegisterNet, ::Colon, j::Int) = [r[j] for r in net.registers]
Base.getindex(net::RegisterNet, ::Colon, k::Symbol) = [m[k] for m in net.vertex_metadata]
Base.getindex(net::RegisterNet, ::Tuple{Colon,Colon}, k::Symbol) = [net.edge_metadata[minmax(ij)...][k] for ij in edges(net)]
Base.getindex(net::RegisterNet, ::Pair{Colon,Colon}, k::Symbol) = [net.directed_edge_metadata[ij][k] for ij in edges(net)]

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
function Base.setindex!(net::RegisterNet, v, ::Pair{Colon,Colon}, k::Symbol)
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
function Base.setindex!(net::RegisterNet, @nospecialize(f::Function), ::Pair{Colon,Colon}, k::Symbol)
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
Base.getindex(r::Register, C) = map(i->r[i], C)

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

include("concurrentsim.jl")

include("plots.jl")

include("quantumchannel.jl")

include("CircuitZoo/CircuitZoo.jl")

include("StatesZoo/StatesZoo.jl")

include("precompile.jl")

end # module
