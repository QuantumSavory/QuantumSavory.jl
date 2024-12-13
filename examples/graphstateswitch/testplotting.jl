using QuantumSavory
using ConcurrentSim
import QuantumClifford: graphstate, Stabilizer, ghz, generate!, canonicalize!, MixedDestabilizer, MixedStabilizer, PauliOperator, dot, tab, logicalzview
using PyCall
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
        graphstates[key_jl] = r.staterefs[1].state[] # Stabilizer state in QuantumOpitcsRepr
    end
    return graphdata, operationdata, graphstates
end

nclients = 5
path_to_graph_data = "examples/graphstateswitch/input/7.pickle" # Graph state data (No. 7 of Fig. 11 in https://quantum-journal.org/papers/q-2020-08-07-305/pdf/)
graphdata, operations, graphstates = get_graphdata_from_pickle(path_to_graph_data, nclients)

@info dot(Stabilizer(graphdata[(1, 3)]), Stabilizer(graphdata[(1, 3)]))

#@info typeof(express(graphstates[(1, 3)]))
#@info observable(reduce(⊗, [fill(Z1,nclients)...]), express(graphstates[(1, 3)]))
# b = reduce(⊗, [fill(Z1,nclients)...])
# k = reduce(⊗, [fill(Z1,nclients)...])
# @info observable(express(b), express(k))
@info graphstates[(1, 3)]
@info graph

g = Graph()
add_vertices!(g, 2)
add_edge!(g, 1, 2)
@info Stabilizer(g)

# nclients = 5
# memory_qubits_switch = nclients # memory slots in switch is equal to the number of clients 

# # The graph of network connectivity. Index 1 corresponds to the switch.
# graph = star_graph(nclients+1)

# switch_registers = Register(memory_qubits_switch)
# client_registers = [Register(1) for _ in 1:nclients] 
# net = RegisterNet(graph, [switch_registers, client_registers...])
# sim = get_time_tracker(net)

# state = X1
# for r in net[1]
#     initialize!(r, state)
# end



# #### 
# pairs_array = collect(d)  # This is now a Vector of (key, value) pairs in insertion order
# @info "Active clients:", pairs_array 

# if no_core # If no core is found, check if a core is present; return first core that arises
#     # core = Vector{Tuple{RegRef, RegRef}}() # maybe use later for multiple concurrent cores
#     core_slot_idcs = []
#     for checkitem in checkset
#         for checkidx in checkitem
#             append!(core_slot_idcs, findfirst(x -> x[2] == checkidx, pairs_array))
#         end
        
#         if all(collect([!isnothing(idx) for idx in core_slot_idcs]))
#             append!(coreslots, [pairs_array[idx][1] for idx in core_slot_idcs])
#             no_core = false # Core is found!
#             #push!(core, coreslots)
#             break # As soon as a core is found it is fixed
#         end
#     end
# end

# #######

# if no_core # If no core is found, check if a core is present; return first core that arises
#     # core = Vector{Tuple{RegRef, RegRef}}() # maybe use later for multiple cores
#     tb_slots = []
#     for t in checkset
#         for i in range(1, length(t))
#             idx = findfirst(x -> x[2] == t[i], pairs_array)
#             if !isnothing(idx)
#                 append!(tb_slots, pairs_array[idx][1])
#             else
#                 tb_slots = [] # Reset slots if one of the qubits is not present in the set currently under consideration
#                 break
#             end
#         end
       
#         if tb_slots != []
#             append!(coreslots, tb_slots)
#             no_core = false # Core is found!
#             break # As soon as a core is found it is fixed
#         end
#     end
# end