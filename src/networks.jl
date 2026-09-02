"""
    RegisterNet(graph::SimpleGraph, registers;
        classical_delay=0, quantum_delay=0, name=nothing, names=String[])
    RegisterNet(registers::Vector{Register};
        classical_delay=0, quantum_delay=0, name=nothing, names=String[])

Store one [`Register`](@ref) for each vertex of an undirected `SimpleGraph`.
If `graph` is omitted, use a chain with one vertex per register.

`RegisterNet` directly supports these read operations from Graphs.jl:
`vertices`, `edges`, `neighbors`, `nv`, `ne`, and `adjacency_matrix`. It is not
a subtype of `Graphs.AbstractGraph`, so other Graphs.jl functions are not part
of this interface. After construction, grow the network with [`add_vertex!`](@ref) and
[`add_edge!`](@ref); those also create the matching classical delay
channels, quantum channels, and message-buffer listeners.

Index a network to move from the network to a register or a register slot:

```julia
net[i]       # Register at vertex i
net[i][j]    # RegRef for slot j of that register
net[i, j]    # the same RegRef
net[:]       # all registers
net[:, j]    # slot j from every register
```

The `name` keyword gives the network a display name. `names` gives display
names to its registers. These names do not replace the integer graph vertex
identifiers. A label can instead be stored as vertex metadata:

```julia
net[1, :label] = "left endpoint"
```

Vertex metadata uses `net[i, :key]`. Undirected edge metadata uses
`net[(i, j), :key]`, and directed edge metadata uses `net[i => j, :key]`.

For more sophisticated metadata handling, check out the independent tag and query capabilities of QuantumSavory.

`classical_delay` and `quantum_delay` each accept a constant or a callable
`(src, dst) -> delay`. A callable is evaluated in both directions of each
edge, so it can give the two directions different delays.

```julia
using Graphs

graph = path_graph(3)
delay(src, dst) = src < dst ? 0.1 : 0.2
net = RegisterNet(graph, [Register(2) for _ in 1:3];
    name="line", names=["left", "middle", "right"],
    classical_delay=delay, quantum_delay=0.05)
```

See [Register Networks](@ref register-networks) for the complete explanation.
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
    name::Union{Nothing,String}
    names::Vector{String}
end

_resolve_link_delay(delay, src, dst) = applicable(delay, src, dst) ? delay(src, dst) : delay

function RegisterNet(graph::SimpleGraph, registers, vertex_metadata, edge_metadata, directed_edge_metadata; classical_delay=0, quantum_delay=0, name=nothing, names=String[])
    env = get_time_tracker(registers[1])

    all_are_at_zero = all(iszero(ConcurrentSim.now(get_time_tracker(r))) && isempty(get_time_tracker(r).heap) && isnothing(get_time_tracker(r).active_proc) for r in registers)
    all_are_same = all(env === get_time_tracker(r) for r in registers)
    if !all_are_same
        if all_are_at_zero
            for r in registers
                r.tag_waiter[] = ChangeNotifier(env)
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

    rn = RegisterNet(graph, registers, vertex_metadata, edge_metadata, directed_edge_metadata, cchannels, cbuffers, qchannels, reverse_lookup, name, names)

    for (i,r) in enumerate(registers)
        r.netparent[] = rn
        r.netindex[] = i
    end

    for (;src,dst) in edges(graph)
        forward_classical_delay = _resolve_link_delay(classical_delay, src, dst)
        forward_quantum_delay = _resolve_link_delay(quantum_delay, src, dst)
        reverse_classical_delay = _resolve_link_delay(classical_delay, dst, src)
        reverse_quantum_delay = _resolve_link_delay(quantum_delay, dst, src)

        cchannels[src=>dst] = DelayQueue{Tag}(env, forward_classical_delay)
        qchannels[src=>dst] = QuantumChannel(env, forward_quantum_delay)
        cchannels[dst=>src] = DelayQueue{Tag}(env, reverse_classical_delay)
        qchannels[dst=>src] = QuantumChannel(env, reverse_quantum_delay)
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

The `classical_delay` and `quantum_delay` keyword arguments each accept either a
single delay used for every channel or a callable `(src, dst) -> delay`. The
callable is evaluated separately for both directions of every graph edge.

```jldoctest
julia> graph = grid([2,2]) # from Graphs.jl
{4, 4} undirected simple Int64 graph

julia> registers = [Register(1), Register(2), Register(1), Register(2)]
4-element Vector{Register}:
 Register
 Register
 Register
 Register

julia> net = RegisterNet(graph, registers)
A network of 4 registers in a graph of 4 edges


julia> neighbors(net, 1) # from Graphs.jl
2-element Graphs.FrozenVector{Int64}:
 2
 3
```
"""
function RegisterNet(graph::SimpleGraph, registers; classical_delay=0, quantum_delay=0, name=nothing, names=String[])
    size(graph, 1) == length(registers) || ArgumentError(lazy"You attempted to construct a `RegisterNet` with a graph of $(size(graph, 1)) vertices but provided a list of $(length(registers)) `Registers`. These two numbers have to match.")
    RegisterNet(graph, registers, empty_vmd(length(registers)), empty_emd(), empty_demd(); classical_delay, quantum_delay, name, names)
end

empty_vmd(n) = [Dict{Symbol,Any}() for _ in 1:n]
empty_emd()  = Dict{Tuple{Int,Int},Dict{Symbol,Any}}()
empty_demd() = Dict{Pair{Int,Int},Dict{Symbol,Any}}()

"""Construct a [`RegisterNet`](@ref) from a given list of [`Register`](@ref)s, defaulting to a chain topology.

```jldoctest
julia> net = RegisterNet([Register(2), Register(4), Register(2)])
A network of 3 registers in a graph of 2 edges

julia> neighbors(net,2) # from Graphs.jl
2-element Graphs.FrozenVector{Int64}:
 1
 3
```
"""
function RegisterNet(registers::Vector{Register}; classical_delay=0, quantum_delay=0, name=nothing, names=String[])
    graph = grid([length(registers)])
    RegisterNet(graph, registers; classical_delay, quantum_delay, name, names)
end

"""Construct a [`RegisterNet`](@ref) with one `Register(nslots)` per graph vertex."""
function RegisterNet(graph::SimpleGraph, nslots::Integer; classical_delay=0, quantum_delay=0, name=nothing, names=String[])
    nslots > 0 || throw(ArgumentError("nslots must be a positive integer"))
    RegisterNet(graph, [Register(Int(nslots)) for _ in 1:nv(graph)]; classical_delay, quantum_delay, name, names)
end

"""Construct a chain [`RegisterNet`](@ref) of `nnodes` registers, each with `nslots` slots."""
function RegisterNet(nnodes::Integer, nslots::Integer; classical_delay=0, quantum_delay=0, name=nothing, names=String[])
    nnodes > 0 || throw(ArgumentError("nnodes must be a positive integer"))
    RegisterNet(grid([Int(nnodes)]), Int(nslots); classical_delay, quantum_delay, name, names)
end



"""
    add_vertex!(net::RegisterNet, r::Register; name=nothing) -> Int

Add `r` as a new vertex of `net`. The new vertex starts with no edges. A
[`MessageBuffer`](@ref) is created for it so later [`add_edge!`](@ref) calls
can attach classical listeners.

The register must either share `net`'s simulation time tracker or not have
been used yet. Returns the new 1-based vertex index.

See also: [`add_edge!`](@ref), [`add_register!`](@ref)
"""
function add_vertex!(net::RegisterNet, r::Register; name::Union{Nothing,String}=nothing)
    parent = r.netparent[]
    if parent !== nothing && parent !== net
        throw(ArgumentError("this Register already belongs to another RegisterNet"))
    end
    if parent === net
        throw(ArgumentError("this Register is already a vertex of this RegisterNet"))
    end

    env = get_time_tracker(net)
    r_env = get_time_tracker(r)
    if r_env !== env
        unused = iszero(ConcurrentSim.now(r_env)) && isempty(r_env.heap) && isnothing(r_env.active_proc)
        if unused
            r.tag_waiter[] = ChangeNotifier(env)
            for i in eachindex(r.locks)
                r.locks[i] = ConcurrentSim.Resource(env, 1)
            end
        else
            throw(ArgumentError("the Register must share the network simulation time tracker, or must not have been used yet"))
        end
    end

    add_vertex!(net.graph)
    push!(net.registers, r)
    push!(net.vertex_metadata, Dict{Symbol,Any}())
    idx = length(net.registers)
    r.netparent[] = net
    r.netindex[] = idx
    net.reverse_lookup[r] = idx
    net.cbuffers[idx] = MessageBuffer(net, idx, NamedTuple{(:src, :channel), Tuple{Int, DelayQueue{Tag}}}[])
    if !isnothing(name)
        while length(net.names) < idx - 1
            push!(net.names, "")
        end
        push!(net.names, name)
    elseif !isempty(net.names)
        push!(net.names, "")
    end
    return idx
end

"""Alias for [`add_vertex!`](@ref)."""
add_register!(net::RegisterNet, r::Register; kwargs...) = add_vertex!(net, r; kwargs...)

"""
    add_edge!(net::RegisterNet, src, dst; classical_delay=0, quantum_delay=0)
    add_edge!(net::RegisterNet, src => dst; classical_delay=0, quantum_delay=0)

Add an undirected graph edge and the two directed classical [`DelayQueue`](@ref)
channels plus two [`QuantumChannel`](@ref)s that `RegisterNet` construction
would have created for that edge. Each endpoint's [`MessageBuffer`](@ref)
starts a listener on the new incoming classical channel.

`classical_delay` and `quantum_delay` accept a constant or a callable
`(src, dst) -> delay`, matching the [`RegisterNet`](@ref) constructor.
"""
function add_edge!(net::RegisterNet, src::Integer, dst::Integer; classical_delay=0, quantum_delay=0)
    src = Int(src)
    dst = Int(dst)
    src == dst && throw(ArgumentError("cannot add a self-loop to RegisterNet"))
    (1 <= src <= nv(net) && 1 <= dst <= nv(net)) || throw(ArgumentError(
        "src and dst must be existing vertices of the RegisterNet",
    ))
    Graphs.has_edge(net.graph, src, dst) && throw(ArgumentError(
        "edge $(src)—$(dst) already exists",
    ))

    env = get_time_tracker(net)
    added = add_edge!(net.graph, src, dst)
    added || throw(ArgumentError("failed to add graph edge $(src)—$(dst)"))

    forward_classical_delay = _resolve_link_delay(classical_delay, src, dst)
    forward_quantum_delay = _resolve_link_delay(quantum_delay, src, dst)
    reverse_classical_delay = _resolve_link_delay(classical_delay, dst, src)
    reverse_quantum_delay = _resolve_link_delay(quantum_delay, dst, src)

    net.cchannels[src => dst] = DelayQueue{Tag}(env, forward_classical_delay)
    net.qchannels[src => dst] = QuantumChannel(env, forward_quantum_delay)
    net.cchannels[dst => src] = DelayQueue{Tag}(env, reverse_classical_delay)
    net.qchannels[dst => src] = QuantumChannel(env, reverse_quantum_delay)

    @process take_loop_mb(env, net.cchannels[src => dst], src, net.cbuffers[dst])
    @process take_loop_mb(env, net.cchannels[dst => src], dst, net.cbuffers[src])
    return true
end

add_edge!(net::RegisterNet, pair::Pair; kwargs...) = add_edge!(net, pair.first, pair.second; kwargs...)
add_edge!(net::RegisterNet, e::Graphs.SimpleEdge; kwargs...) = add_edge!(net, e.src, e.dst; kwargs...)


"""Get the parent network of a [`Register`](@ref) or parent register of a [`RegRef`](@ref)."""
function Base.parent(r::Register)
    return r.netparent[]
end

"""Get the index of a [`Register`](@ref) / [`RegRef`](@ref) in the parent network / register."""
function parentindex end

parentindex(r::Register) = r.netindex[]

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
    net = parent(reg)
    idx = parentindex(reg)
    isnothing(net) && throw(ArgumentError("The register does not have a parent network and thus it does not have an assigned message buffer."))
    return messagebuffer(net, idx)
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
