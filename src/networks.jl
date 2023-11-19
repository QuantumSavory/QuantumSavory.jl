"""
A network of [`Register`](@ref)s with convenient graph API as well.
"""
struct RegisterNet
    graph::SimpleGraph{Int64}
    registers::Vector{Register}
    vertex_metadata::Vector{Dict{Symbol,Any}}
    edge_metadata::Dict{Tuple{Int,Int},Dict{Symbol,Any}}
    directed_edge_metadata::Dict{Pair{Int,Int},Dict{Symbol,Any}}
        all_are_at_zero = all(iszero(ConcurrentSim.now(get_time_tracker(r))) && isempty(get_time_tracker(r).heap) && isnothing(get_time_tracker(r).active_proc) for r in registers)
        env = get_time_tracker(registers[1])
        all_are_same = all(env === get_time_tracker(r) for r in registers)
        if !all_are_same
            if all_are_at_zero
                for r in registers
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
    size(graph, 1) == length(registers) || ArgumentError(lazy"You attempted to construct a `RegisterNet` with a graph of $(size(graph, 1)) vertices but provided a list of $(length(registers)) `Registers`. These two numbers have to match.")
    RegisterNet(graph, registers, empty_vmd(length(registers)), empty_emd(), empty_demd())
end

empty_vmd(n) = [Dict{Symbol,Any}() for _ in 1:n]
empty_emd()  = Dict{Tuple{Int,Int},Dict{Symbol,Any}}()
empty_demd() = Dict{Pair{Int,Int},Dict{Symbol,Any}}()

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
