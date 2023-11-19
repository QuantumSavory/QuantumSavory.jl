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
    tags::Vector{Set{Tag}}
end

function Register(traits, reprs, bg, sr, si, at)
    env = ConcurrentSim.Simulation()
    Register(traits, reprs, bg, sr, si, at, env, [ConcurrentSim.Resource(env) for _ in traits], [Set{Tag}() for _ in traits])
end
Register(traits,reprs,bg,sr,si) = Register(traits,reprs,bg,sr,si,zeros(length(traits)))
Register(traits,reprs,bg) = Register(traits,reprs,bg,fill(nothing,length(traits)),zeros(Int,length(traits)),zeros(length(traits)))
Register(traits,bg::Base.AbstractVecOrTuple{<:Union{Nothing,<:AbstractBackground}}) = Register(traits,default_repr.(traits),bg)
Register(traits,reprs::Base.AbstractVecOrTuple{<:AbstractRepresentation}) = Register(traits,reprs,fill(nothing,length(traits)))
Register(traits) = Register(traits,default_repr.(traits))
Register(nqubits::Int) = Register([Qubit() for _ in 1:nqubits])
Register(nqubits::Int,repr::AbstractRepresentation) = Register(fill(Qubit(),nqubits),fill(repr,nqubits))
Register(nqubits::Int,bg::AbstractBackground) = Register(fill(Qubit(),nqubits),fill(bg,nqubits))

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

#Base.:(==)(r1::Register, r2::Register) =

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
