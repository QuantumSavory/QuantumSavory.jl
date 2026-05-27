using Graphs
using QuantumSavory
using Random
using Statistics

"""
    node_index(n, row, col)

Return the vertex index for `(row, col)` in an `n` by `n` square lattice.
Alice is vertex 1 and Bob is vertex `n^2`.
"""
function node_index(n::Integer, row::Integer, col::Integer)
    1 <= row <= n || throw(ArgumentError("row must be in 1:n"))
    1 <= col <= n || throw(ArgumentError("col must be in 1:n"))
    return (row - 1) * n + col
end

"""Create the square repeater lattice used in this example."""
function square_lattice_graph(n::Integer)
    n >= 2 || throw(ArgumentError("n must be at least 2"))
    graph = SimpleGraph(n * n)
    for row in 1:n, col in 1:n
        col < n && add_edge!(graph, node_index(n, row, col), node_index(n, row, col + 1))
        row < n && add_edge!(graph, node_index(n, row, col), node_index(n, row + 1, col))
    end
    return graph
end

"""Return a `RegisterNet` for plotting or extending the percolation trial."""
function percolation_register_net(n::Integer)
    graph = square_lattice_graph(n)
    return RegisterNet(graph, [Register(1) for _ in 1:nv(graph)])
end

"""Coordinates used by the interactive lattice plot."""
function lattice_coordinates(n::Integer)
    return Dict(node_index(n, row, col) => (Float64(col), Float64(n - row + 1))
                for row in 1:n for col in 1:n)
end

edge_tuple(edge) = src(edge) < dst(edge) ? (src(edge), dst(edge)) : (dst(edge), src(edge))

"""Build a graph containing only successfully heralded elementary links."""
function heralded_subgraph(graph::SimpleGraph, open_edges)
    subgraph = SimpleGraph(nv(graph))
    for (u, v) in open_edges
        add_edge!(subgraph, u, v)
    end
    return subgraph
end

"""Breadth-first shortest path on the heralded-link subgraph."""
function shortest_open_path(graph::SimpleGraph, source::Integer, target::Integer)
    source == target && return [source]
    visited = falses(nv(graph))
    parent = zeros(Int, nv(graph))
    queue = [Int(source)]
    visited[source] = true
    head = 1
    while head <= length(queue)
        node = queue[head]
        head += 1
        for neighbor in neighbors(graph, node)
            visited[neighbor] && continue
            visited[neighbor] = true
            parent[neighbor] = node
            neighbor == target && break
            push!(queue, neighbor)
        end
        visited[target] && break
    end
    visited[target] || return Int[]

    path = Int[target]
    while last(path) != source
        push!(path, parent[last(path)])
    end
    reverse!(path)
    return path
end

"""
    swapped_path_fidelity(link_fidelity, hops; swap_visibility=1.0)

Estimate the final Bell-pair fidelity after entanglement swapping over a path.

The model treats each elementary Bell pair as Werner-like, converts its fidelity
to a correlation visibility, multiplies visibilities through the path and the
local swap operations, then converts back to fidelity.
"""
function swapped_path_fidelity(link_fidelity::Real, hops::Integer; swap_visibility::Real=1.0)
    hops >= 1 || throw(ArgumentError("hops must be at least 1"))
    0.25 <= link_fidelity <= 1.0 || throw(ArgumentError("link_fidelity must be in [0.25, 1]"))
    0.0 <= swap_visibility <= 1.0 || throw(ArgumentError("swap_visibility must be in [0, 1]"))

    elementary_visibility = (4 * link_fidelity - 1) / 3
    final_visibility = elementary_visibility^hops * swap_visibility^max(hops - 1, 0)
    return (1 + 3 * final_visibility) / 4
end

"""
    run_percolation_trial(; n=5, link_success=0.55, link_fidelity=0.97,
                            swap_visibility=0.99, seed=1)

Run one heralded entanglement-percolation trial on an `n` by `n` lattice.

Each nearest-neighbor channel independently succeeds with probability
`link_success`. If Alice and Bob are connected by the successful elementary
Bell links, the shortest available path is selected and assigned an estimated
end-to-end swapped-pair fidelity.
"""
function run_percolation_trial(;
    n::Integer=5,
    link_success::Real=0.55,
    link_fidelity::Real=0.97,
    swap_visibility::Real=0.99,
    seed::Integer=1,
)
    0.0 <= link_success <= 1.0 || throw(ArgumentError("link_success must be in [0, 1]"))

    rng = MersenneTwister(seed)
    graph = square_lattice_graph(n)
    open_edges = Tuple{Int, Int}[]
    for edge in edges(graph)
        rand(rng) <= link_success && push!(open_edges, edge_tuple(edge))
    end
    open_graph = heralded_subgraph(graph, open_edges)
    source = 1
    target = n * n
    selected_path = shortest_open_path(open_graph, source, target)
    path_hops = isempty(selected_path) ? 0 : length(selected_path) - 1
    fidelity = path_hops == 0 ? nothing :
        swapped_path_fidelity(link_fidelity, path_hops; swap_visibility)

    return (;
        n = Int(n),
        graph,
        open_graph,
        open_edges,
        source,
        target,
        selected_path,
        connected = !isempty(selected_path),
        path_hops,
        estimated_fidelity = fidelity,
        link_success = Float64(link_success),
        link_fidelity = Float64(link_fidelity),
        swap_visibility = Float64(swap_visibility),
        seed = Int(seed),
    )
end

"""Run repeated independent trials and summarize Alice-Bob connectivity."""
function run_percolation_ensemble(;
    n::Integer=5,
    link_success::Real=0.55,
    link_fidelity::Real=0.97,
    swap_visibility::Real=0.99,
    samples::Integer=200,
    seed::Integer=1,
)
    samples >= 1 || throw(ArgumentError("samples must be at least 1"))
    trials = [run_percolation_trial(;
        n,
        link_success,
        link_fidelity,
        swap_visibility,
        seed = seed + i - 1,
    ) for i in 1:samples]

    connected = filter(trial -> trial.connected, trials)
    fidelities = [trial.estimated_fidelity for trial in connected]
    hops = [trial.path_hops for trial in connected]

    return (;
        trials,
        samples = Int(samples),
        connected_count = length(connected),
        success_rate = length(connected) / samples,
        mean_path_hops = isempty(hops) ? NaN : mean(hops),
        mean_estimated_fidelity = isempty(fidelities) ? NaN : mean(fidelities),
    )
end

function print_trial_summary(trial)
    println("Heralded entanglement percolation on a $(trial.n)x$(trial.n) lattice")
    println("link success probability: $(trial.link_success)")
    println("open elementary links: $(length(trial.open_edges)) / $(ne(trial.graph))")
    if trial.connected
        println("Alice and Bob connected: yes")
        println("selected path: $(join(trial.selected_path, " -> "))")
        println("path hops: $(trial.path_hops)")
        println("estimated swapped-pair fidelity: $(round(trial.estimated_fidelity; digits=4))")
    else
        println("Alice and Bob connected: no")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    trial = run_percolation_trial()
    print_trial_summary(trial)
    @assert trial.n == 5
    @assert 0 <= length(trial.open_edges) <= ne(trial.graph)
end
