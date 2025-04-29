using QuantumClifford: Stabilizer, canonicalize!, sSWAP
using QuantumSavory
using Graphs: random_regular_graph, edges
using QuantumOpticsBase
##

function order_state!(state, current_order::Vector{Int})
    # Loop over each index 
    for i in 1:length(current_order)
        # If the qubit at position i isn't i, swap it with wherever qubit i lives
        while current_order[i] != i
            @info "current order $(current_order)"
            # Find which position holds the qubit i
            correct_index = findfirst(==(i), current_order)

            # Swap the qubits physically
            apply!(state, sSWAP(current_order[i], current_order[correct_index]); phases=true)
            current_order[i], current_order[correct_index] = current_order[correct_index], current_order[i]
            @info "swapped indices $((i,correct_index)) to get $(collect(edges(graphstate(state)[1])))"
        end

    end
    @info "current order $(current_order)"
end



n = 4 # number of qubits

# Define graph
g = random_regular_graph(n, 2, seed=2)
refstate = Stabilizer(g)  
# plt = graphplot(g, names = collect(vertices(g)), marker=:circle)
# display(plt)

# Set up registers
switch = Register(fill(Qubit(), n), fill(CliffordRepr(), n)) 
clients = [Register(1, CliffordRepr()) for _ in 1:n]

# Initialize Bell pairs
bell = StabilizerState("XX ZZ")
for i in 1:n
    initialize!([clients[i][1], switch[i]], bell)
end

# Apply CZ gates at the switch according to graph
measured_out = []
for i in 1:n
    neighs = copy(neighbors(g, i))
    @info i, collect(edges(g))
    @info "switch indices $(switch.stateindices)"
    for j in neighs
        apply!([switch[i], switch[j]], ZCZ)
        @info "Apply CZ between $((i,j))"
        rem_edge!(g, i, j)
        @info collect(edges(g))
    end

    # Measure qubit in X basis and apply Z correction
    xmeas = project_traceout!(switch[i], σˣ)
    push!(measured_out, i)
    if xmeas == 2
        apply!(clients[i][1], Z)
    end
    
end

@info "reference state: $(canonicalize!(refstate))"
# @info "reference graph: $(collect(edges(graphstate(refstate)[1])))"

generated_state = clients[1].staterefs[1].state[]
@info "generated state: $(canonicalize!(generated_state))"
# @info "generated graph: $(collect(edges(graphstate(generated_state)[1])))"
@info "clients indices $([clients[i].stateindices[1] for i in 1:n])"

@info "ORDER STATE"
current_order = [clients[i].stateindices[1] for i in 1:n]
order_state!(generated_state, current_order)
@info "generated state: $(canonicalize!(generated_state))"
@info "Fidelity: $(abs(Ket(canonicalize!(refstate))'*Ket(canonicalize!(generated_state)))^2)"

state = StabilizerState("XZZ ZXZ ZZX")
testreg = Register(fill(Qubit(),3), fill(CliffordRepr(), 3))
initialize!(testreg[1:3], state)
@info observable(testreg[1:3], projector(state))