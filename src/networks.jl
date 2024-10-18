"""
A network of [`Register`](@ref)s with convenient graph API as well.
"""
struct RegisterNet
    graph::SimpleGraph{Int64}
    registers::Vector{Register}
    vertex_metadata::Vector{Dict{Symbol,Any}}
    edge_metadata::Dict{Tuple{Int,Int},Dict{Symbol,Any}}
    directed_edge_metadata::Dict{Pair{Int,Int},Dict{Symbol,Any}}
    cchannels::Dict{Pair{Int,Int},DelayQueue{Tag}} # Dict{src=>dst, DelayQueue}
    cbuffers::Dict{Int,MessageBuffer{Tag}} # Dict{dst, MessageBuffer}
    qchannels::Dict{Pair{Int,Int},Any} # Dict{src=>dst, QuantumChannel}
    reverse_lookup::IdDict{Register,Int}
end

function RegisterNet(graph::SimpleGraph, registers, vertex_metadata, edge_metadata, directed_edge_metadata; classical_delay=0, quantum_delay=0)
    env = get_time_tracker(registers[1])

    all_are_at_zero = all(iszero(ConcurrentSim.now(get_time_tracker(r))) && isempty(get_time_tracker(r).heap) && isnothing(get_time_tracker(r).active_proc) for r in registers)
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

    cchannels = Dict{Pair{Int,Int},DelayQueue{Tag}}()
    qchannels = Dict{Pair{Int,Int},Any}()
    cbuffers = Dict{Int,MessageBuffer{Tag}}()
    reverse_lookup = IdDict{Register,Int}()

    rn = RegisterNet(graph, registers, vertex_metadata, edge_metadata, directed_edge_metadata, cchannels, cbuffers, qchannels, reverse_lookup)

    for r in registers
        r.netparent[] = rn
    end

    for (;src,dst) in edges(graph)
        cchannels[src=>dst] = DelayQueue{Tag}(env, classical_delay)
        qchannels[src=>dst] = QuantumChannel(env, quantum_delay)
        cchannels[dst=>src] = DelayQueue{Tag}(env, classical_delay)
        qchannels[dst=>src] = QuantumChannel(env, quantum_delay)
    end
    for (v,r) in zip(vertices(graph), registers)
        channels = [(;src=w, channel=cchannels[w=>v]) for w in neighbors(graph, v)]
        cbuffers[v] = MessageBuffer(rn, v, channels)
    end
    for (v,r) in zip(vertices(graph), registers)
        reverse_lookup[r] = v
    end

    return rn
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
function RegisterNet(graph::SimpleGraph, registers; classical_delay=0, quantum_delay=0)
    size(graph, 1) == length(registers) || ArgumentError(lazy"You attempted to construct a `RegisterNet` with a graph of $(size(graph, 1)) vertices but provided a list of $(length(registers)) `Registers`. These two numbers have to match.")
    RegisterNet(graph, registers, empty_vmd(length(registers)), empty_emd(), empty_demd(); classical_delay, quantum_delay)
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
function RegisterNet(registers::Vector{Register}; classical_delay=0, quantum_delay=0)
    graph = grid([length(registers)])
    RegisterNet(graph, registers; classical_delay, quantum_delay)
end

function add_register!(net::RegisterNet, r::Register)
    add_vertex!(net.graph)
    push!(net.registers, r)
    return length(Graph())
end

## Channel accessors

"""Get a handle to a classical channel between two registers.

Usually used for sending classical messages between registers.
It can be used for receiving as well, but a more convenient choice is [`messagebuffer`](@ref),
which is a message buffer listening to **all** channels sending to a given destination register.

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

See also: [`qchannel`](@ref), [`messagebuffer`](@ref)
"""
function channel(net::RegisterNet, args...; permit_forward=false)
    return achannel(net, args..., Val{:C}(); permit_forward)
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
    return achannel(net, args..., Val{:Q}())
end

"""
$TYPEDSIGNATURES

Get a handle to a classical message buffer corresponding to all channels sending to a given destination register.

See also: [`channel`](@ref)
"""
function messagebuffer(net::RegisterNet, dst::Int)
    return net.cbuffers[dst]
end

"""
$TYPEDSIGNATURES

Get a handle to a classical message buffer corresponding to all channels sending to a given destination register.

See also: [`channel`](@ref)
"""
function messagebuffer(ref::RegOrRegRef)
    reg = get_register(ref)
    net = reg.netparent[]
    return messagebuffer(net, net.reverse_lookup[reg])
end

function achannel(net::RegisterNet, src::Int, dst::Int, ::Val{:C}; permit_forward=false)
    pair = src=>dst
    if permit_forward && !haskey(net.cchannels, pair)
        return ChannelForwarder(net, src, dst)
    elseif haskey(net.cchannels, pair)
        return net.cchannels[pair]
    else
        error(lazy"There is no direct classical channel between the nodes in the request $(src)=>$(dst). Consider using `channel(...; permit_forward=true)` to instead encapsulate the message in a forwarder packet and send it to the first node in the shortest path.")
    end
end

function achannel(net::RegisterNet, src::Int, dst::Int, ::Val{:Q})
    return net.qchannels[src=>dst]
end

function achannel(net::RegisterNet, fromreg::Register, to::Int, v::Val{Q}; kw...) where {Q}
    achannel(net, net.reverse_lookup[fromreg], to, v; kw...)
end

function achannel(net::RegisterNet, from::Int, toreg::Register, v::Val{Q}; kw...) where {Q}
    achannel(net, from, net.reverse_lookup[toreg], v; kw...)
end

function achannel(net::RegisterNet, fromreg::Register, toreg::Register, v::Val{Q}; kw...) where {Q}
    achannel(net, net.reverse_lookup[fromreg], net.reverse_lookup[toreg], v; kw...)
end

function achannel(net::RegisterNet, fromto::Edge, v::Val{Q}; kw...) where {Q}
    (;src,dst) = fromto
    achannel(net, src, dst, v; kw...)
end

function achannel(net::RegisterNet, fromto::Pair, v::Val{Q}; kw...) where {Q}
    (src,dst) = fromto
    achannel(net, src, dst, v; kw...)
end
