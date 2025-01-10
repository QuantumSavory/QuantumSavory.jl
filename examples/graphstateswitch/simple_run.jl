using DataFrames
using CSV
using Graphs, GraphRecipes, Plots
import QuantumClifford: graphstate, Stabilizer
using PyCall
include("setup_one_clientregister.jl")

@pyimport pickle
@pyimport networkx

# Costum function to view graph
function viewgraph(g)
    graphplot(g,
        # nodes
        names = 1:nv(g),
        fontsize = 10,
        nodeshape = :circle,
        markersize = 0.15,
        markerstrokewidth = 2,
        # edges
        linewidth = 2,
        curves = false,
        # save to file
        #filename = "examples/graphstateswitch/graph_$(counter).png"
    )
end

# Costum function to load the graph data
function get_graphdata_from_pickle(path, nclients)
    graphdata = Dict{Tuple, Graph}()
    operationdata = Dict{Tuple, Any}()
    graphstates = Dict{Tuple, Any}()
    graphdata_py = pickle.load(open(path, "r"))
    

    for (key, value) in graphdata_py # value = [lc equivalent graph, transition gates
        r = Register(nclients)
        for slot in r
            initialize!(slot, X1)
        end
        graph_py = value[1]
        graph_jl = Graph()
        add_vertices!(graph_jl, networkx.number_of_nodes(graph_py))
        for edge in value[1].edges
            edgejl = map(x -> x + 1, Tuple(edge)) # +1 because Julia is 1-indexed
            add_edge!(graph_jl, edgejl) 
            apply!((r[edgejl[1]], r[edgejl[2]]), ZCZ)
        end
        key_jl = map(x -> x + 1, Tuple(key)) # +1 because Julia is 1-indexed
        graphdata[key_jl] = graph_jl
        operationdata[key_jl] = value[2][1,:] # Transition gates
        graphstates[key_jl] = copy(r.staterefs[1].state[]) # Stabilizer state in QuantumOpitcsRepr
    end
    return graphdata, operationdata, graphstates
end

nclients = 5
path_to_graph_data = "examples/graphstateswitch/input/7.pickle" # Graph state data (No. 7 of Fig. 11 in https://quantum-journal.org/papers/q-2020-08-07-305/pdf/)
link_success_prob = 1.
nruns = 1

graphdata, operations, graphstates = get_graphdata_from_pickle(path_to_graph_data, nclients)
# for (key, value) in graphdata
#     @info "The lc quivalent graph with vertex cover $(key) has $(nv(value)) vertices and $(ne(value)) edges"
#     #@info "The transition gates are $(operations[key])"
#     @info "The stabilizer state is $(graphstates[key])"
# end

# simple graph
# nclients = 3
# a = Register(3)
# g = Graph(3)
# add_edge!(g, 1, 2)
# add_edge!(g, 2, 3)
# graphdata = Dict( (2,) => g )
# initialize!((a[1],a[2],a[3]), X1⊗X1⊗X1)  # Initialize a in |+⟩ state

# apply!((a[1],a[2]), ZCZ)  
# apply!((a[2],a[3]), ZCZ)
# refstate = copy(a.staterefs[1].state[])
# graphstates = Dict( (2,) => refstate )

# Prepare simulation data storage
results_per_client = DataFrame[]
distribution_times = Float64[]
fidelities = Float64[]
elapsed_times = Float64[]

# Run the simulation nruns times
for i in 1:nruns
    sim = prepare_simulation(nclients, graphdata, operations, graphstates; link_success_prob)
    elapsed_time = @elapsed run(sim) 
    # Extract data from consumer.log
    # distribution_time, fidelity = consumer.log[1]
    # append!(distribution_times, distribution_time)
    # append!(fidelities, fidelity)
    append!(elapsed_times, elapsed_time)
    @info "Run $i completed"
end

# Fill the results DataFrame
# results = DataFrame(
#     distribution_times = distribution_times,
#     fidelities = fidelities,
#     elapsed_times = elapsed_times
# )
# results.num_remote_nodes .= nclients
# results.link_success_prob .= link_success_prob
# results.mem_depolar_prob .= mem_depolar_prob
# results.type .= name

# push!(results_per_client, results)

# results_total = vcat(results_per_client...)

# # Group and summarize the data
# grouped_df = groupby(results_total, [:num_remote_nodes, :distribution_times])
# summary_df = combine(
#     grouped_df,
#     :fidelities => mean => :mean_fidelities,
#     :fidelities => std => :std_fidelities
# )

# @info summary_df

# Uncomment to write results to CSV
# CSV.write("examples/piecemakerswitch/output/piecemaker-eventdriven.csv", results_total)
# CSV.write("examples/piecemakerswitch/output/piecemaker-eventdriven_summary.csv", summary_df)
# viewgraph(graphdata[(2,4)
# viewgraph(SimpleGraph{Int64}(6, [[3, 5], [3, 5], [1, 2, 5], [5], [1, 2, 3, 4]]))

# (3,4) -> 0.25
# (2,4) -> 1 / 0.5
# (2,5) -> 0
# (1,3) -> 0
