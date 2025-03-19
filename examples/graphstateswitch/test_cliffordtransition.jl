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

        # Initialize a reference register in |+⟩ state
        r = Register(n)
        initialize!(r[1:n], reduce(⊗, fill(X1,n)))  

        # Generate graph in Julia and apply the CZ gates to reference register
        graph_jl = Graph()
        add_vertices!(graph_jl, n)
        for edge in value[1].edges
            edgejl = map(x -> x + 1, Tuple(edge)) # +1 because Julia is 1-indexed
            add_edge!(graph_jl, edgejl) 
            apply!((r[edgejl[1]], r[edgejl[2]]), ZCZ)
        end

        # The core represents the key
        key_jl = map(x -> x + 1, Tuple(key)) # +1 because Julia is 1-indexed
        graphdata[key_jl] = (graph_jl, r)
        operationdata[key_jl] = [permutedims(value[2])] # Transition gate sets
    end
    return graphdata, operationdata
end

function apply_cliffords!(reg, cliffords)
    S = express(projector(Z1) + im*projector(Z2))
    @debug S
    mapping = Dict(
        'S' => S,
        'H' => H,
        'Z' => Z
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

n = 5
trialset = ["I", "H", "S", "HS", "SH", "SHS", "HSH"]

operationsdatavalid = Dict{Tuple, Any}()

core = (2,4)
origstate = graphdata[core][2].staterefs[1].state[]
@info typeof(collect(product(repeat([trialset],n)...))[1])
for (key,value) in graphdata
    
    operationsdatavalid_per_core = fill("", 1, 5)
    for gateset in collect(product(repeat([trialset],n)...))
        gateset = collect(gateset)
        r = deepcopy(value[2])

        apply_cliffords!(r, gateset)
        fidel = abs(dagger(origstate)*r.staterefs[1].state[])^2
        if fidel > 0.9
            if operationsdatavalid_per_core == fill("", 1, 5)
                operationsdatavalid_per_core[1,:] = gateset
            else
                temp = fill("", 1, 5)
                temp[1,:] = gateset
                operationsdatavalid_per_core = [operationsdatavalid_per_core; temp]
            end
            @info fidel
        end
    end
    operationsdatavalid[key] = operationsdatavalid_per_core

end

@info operationsdatavalid