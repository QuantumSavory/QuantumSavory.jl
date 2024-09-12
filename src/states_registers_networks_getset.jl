## Registers

Base.getindex(r::Register, i::Int) = RegRef(r,i)
Base.getindex(r::Register, C) = map(i->r[i], C)
Base.length(r::Register) = length(r.stateindices)
Base.iterate(r::Register, state=1) = state > length(r) ? nothing : (r[state],state+1)

## Networks

# Graph interface
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
Base.getindex(net::RegisterNet, ::Tuple{Colon,Colon}, k::Symbol) = [net.edge_metadata[minmax(Tuple(ij)...)][k] for ij in edges(net)]
Base.getindex(net::RegisterNet, ::Pair{Colon,Colon}, k::Symbol) = [net.directed_edge_metadata[Pair(ij)][k] for ij in edges(net)]

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
