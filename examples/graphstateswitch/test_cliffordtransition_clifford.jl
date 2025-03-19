using QuantumSavory
using QuantumSavory.CircuitZoo
using QuantumSavory.ProtocolZoo
using NetworkLayout
using Random, StatsBase
using Graphs, GraphRecipes
using PyCall
using DataFrames, StatsPlots
using CSV
using IterTools
using QuantumClifford: graphstate, sHadamard, sPhase, canonicalize!, Stabilizer, stabilizerview

@pyimport pickle
@pyimport networkx


# Costum function to load the graph data
function get_graphdata_from_pickle(path)
    
    graphdata = Dict{Tuple, Tuple{Graph, Any}}()
    operationdata = Dict{Tuple, Any}()
    
    # Load the graph data in python from pickle file
    graphdata_py = pickle.load(open(path, "r"))
    
    for (key, value) in graphdata_py # value = [lc equivalent graph, transition gates
        graph_py = value[1]
        n = networkx.number_of_nodes(graph_py)

        # Generate graph in Julia and apply the CZ gates to reference register
        graph_jl = Graph()
        add_vertices!(graph_jl, n)
        for edge in value[1].edges
            edgejl = map(x -> x + 1, Tuple(edge)) # +1 because Julia is 1-indexed
            add_edge!(graph_jl, edgejl) 
        end

        # Initialize a reference register using the graph
        r = Register(n, CliffordRepr())
        initialize!(r[1:n], StabilizerState(Stabilizer(graph_jl)))

        # The core represents the key
        key_jl = map(x -> x + 1, Tuple(key)) # +1 because Julia is 1-indexed
        @info collect(edges(graph_jl))
        graphdata[key_jl] = (graph_jl, r)
        operationdata[key_jl] = value[2][1,:] # Transition gate sets
    end
    return graphdata, operationdata
end

function apply_cliffords!(reg, cliffords)
    mapping = Dict(
        'S' => sPhase,
        'H' => sHadamard,
    )
    for (i, clifford) in enumerate(cliffords)
        for gate in reverse(clifford)
            if gate == 'I'
                continue
            end
            apply!(reg[i], mapping[gate])
            @debug "Applied $(gate) to qubit $(i)"
            
        end
    end
end


path_to_graph_data = "examples/graphstateswitch/input/7_20250127.pickle"
graphdata, operationdata = get_graphdata_from_pickle(path_to_graph_data)


for (key, gates) in operationdata

    cliffords = operationdata[key]
    @info "Core $(key) with cliffords $(cliffords)"

    @info collect(edges(graphdata[key][1]))
    apply_cliffords!(graphdata[key][2], cliffords)
    graph, hadamard_idx, iphase_idx, flips_idx  = graphstate(graphdata[key][2].staterefs[1].state[])
    @info collect(edges(graph))
    if length(flips_idx) > 0 || length(hadamard_idx) > 0 || length(iphase_idx) > 0
        @info "Applied H -> $(hadamard_idx), S-> $(iphase_idx) and Z -> $(flips_idx)"
    else
        @info "No Clifford gates applied.\n\n"
    end
end

