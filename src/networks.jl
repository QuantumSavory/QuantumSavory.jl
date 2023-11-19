"""
A network of [`Register`](@ref)s with convenient graph API as well.
"""
struct RegisterNet
    graph::SimpleGraph{Int64}
    registers::Vector{Register}
    vertex_metadata::Vector{Dict{Symbol,Any}}
    edge_metadata::Dict{Tuple{Int,Int},Dict{Symbol,Any}}
    directed_edge_metadata::Dict{Pair{Int,Int},Dict{Symbol,Any}}
    cchannels::Dict{Pair{Int,Int},Any}
    qchannels::Dict{Pair{Int,Int},Any}
    reverse_lookup::IdDict{Register,Int}
    function RegisterNet(graph, registers, vertex_metadata, edge_metadata, directed_edge_metadata, cchannels::Dict{Pair{Int,Int},Any}, qchannels::Dict{Pair{Int,Int},Any}, reverse_lookup::IdDict{Register,Int})
        # TODO check that the env in cchannels and qchannels and registers all match
        # TODO check reverse_lookup for correctness
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
        new(graph, registers, vertex_metadata, edge_metadata, directed_edge_metadata, cchannels, qchannels, reverse_lookup)
    end
end

function RegisterNet(graph::SimpleGraph, registers, vertex_metadata, edge_metadata, directed_edge_metadata)
    cchannels = Dict{Pair{Int,Int},Any}()
    qchannels = Dict{Pair{Int,Int},Any}()
    env = get_time_tracker(registers[1])
    for (;src,dst) in edges(graph)
        cchannels[src=>dst] = DelayQueue{Tag}(env, 0)
        qchannels[src=>dst] = QuantumChannel(env, 0)
        cchannels[dst=>src] = DelayQueue{Tag}(env, 0)
        qchannels[dst=>src] = QuantumChannel(env, 0)
    end
    reverse_lookup = IdDict{Register,Int}()
    for (v,r) in zip(vertices(graph), registers)
        reverse_lookup[r] = v
    end
    RegisterNet(graph, registers, vertex_metadata, edge_metadata, directed_edge_metadata, cchannels, qchannels, reverse_lookup)
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
function RegisterNet(graph::SimpleGraph, registers)
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

## Channel accessors

"""Get a handle to a classical channel between two registers.

```jldoctest
julia> net = RegisterNet([Register(2), Register(2), Register(2)]) # defaults to a chain topology
A network of 3 registers in a graph of 2 edges

julia> channel(net, 1=>2)
ConcurrentSim.DelayQueue{Tag}(ConcurrentSim.QueueStore{Tag, Int64}, 0.0)

julia> channel(net, 1=>2)
ConcurrentSim.DelayQueue{Tag}(ConcurrentSim.QueueStore{Tag, Int64}, 0.0)

julia> channel(net, 1=>2) === channel(net, net[1]=>net[2])
true
```

See also: [`qchannel`](@ref)
"""
function channel(net::RegisterNet, args...)
    return achannel(net, args..., Val{false}())
end

"""Get a handle to a quantum channel between two registers.

```jldoctest
julia> net = RegisterNet([Register(2), Register(2), Register(2)]) # defaults to a chain topology
A network of 3 registers in a graph of 2 edges

julia> qchannel(net, 1=>2)
QuantumChannel{Qubit}(Qubit(), ConcurrentSim.DelayQueue{Register}(ConcurrentSim.QueueStore{Register, Int64}, 0.0), nothing)

julia> qchannel(net, 1=>2) === qchannel(net, net[1]=>net[2])
true
```

See also: [`channel`](@ref)
"""
function qchannel(net::RegisterNet, args...)
    return achannel(net, args..., Val{true}())
end

function achannel(net::RegisterNet, src::Int, dst::Int, ::Val{Q}) where {Q}
    if Q
        return net.qchannels[src=>dst]
    else
        return net.cchannels[src=>dst]
    end
end

function achannel(net::RegisterNet, fromreg::Register, to::Int, v::Val{Q}) where {Q}
    achannel(net, net.reverse_lookup[fromreg], to, v)
end

function achannel(net::RegisterNet, from::Int, toreg::Register, v::Val{Q}) where {Q}
    achannel(net, from, net.reverse_lookup[toreg], v)
end

function achannel(net::RegisterNet, fromreg::Register, toreg::Register, v::Val{Q}) where {Q}
    achannel(net, net.reverse_lookup[fromreg], net.reverse_lookup[toreg], v)
end

function achannel(net::RegisterNet, fromto::Edge, v::Val{Q}) where {Q}
    (;src,dst) = fromto
    achannel(net, src, dst, v)
end

function achannel(net::RegisterNet, fromto::Pair, v::Val{Q}) where {Q}
    (src,dst) = fromto
    achannel(net, src, dst, v)
end
