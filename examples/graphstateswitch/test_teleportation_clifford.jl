using QuantumSavory
using QuantumSavory.CircuitZoo
using QuantumClifford: graphstate, MixedDestabilizer, PauliOperator, projectZ!, BellMeasurement, projectZrand!, traceout!, Stabilizer, sCNOT, sHadamard, stabilizerview, Reset, sSWAP, canonicalize!
using QuantumSavory: Register, initialize!, apply!, express, nsubsystems
using Graphs

function order_state!(reg, orderlist)
    @assert length(reg) == length(orderlist)

    #orderlist = deepcopy(orderlist)
    # Loop over each index i
    for i in 1:length(orderlist)
        # If the qubit at position i isn't i, swap it with wherever qubit i lives
        while orderlist[i] != i
            # Find which position holds the qubit i
            correct_index = findfirst(==(i), orderlist)

            # Swap the register qubits physically
            apply!((reg[i], reg[correct_index]), sSWAP)

            # Swap the entries in orderlist
            orderlist[i], orderlist[correct_index] = orderlist[correct_index], orderlist[i]
        end
    end
end

# Quantum registers holding the qubits
repr = [CliffordRepr(), QuantumOpticsRepr()]
take = 1
a = Register(6, repr[take]) # switch
b = Register(3, repr[take]) # nodes register

# Create a graph state
graph = Graph()
add_vertices!(graph, 3)
for edge in [(1,2), (2,3)]
    add_edge!(graph, edge)
end
state = StabilizerState(Stabilizer(graph))
initialize!((a[1], a[2], a[3]), state)  # Initialize a in the graph state
refstate = deepcopy(a.staterefs[1].state[]) # Save the reference state

bell = StabilizerState("ZZ XX")
initialize!((a[4], b[1]), bell) 
initialize!((a[5], b[2]), bell) 
initialize!((a[6], b[3]), bell) 

# Teleportation protocol
teleportation_order = [1,3,2]
for i in teleportation_order
    tobeteleported = a[i]
    apply!((tobeteleported, a[3+i]), CNOT)
    apply!(tobeteleported, sHadamard)

    zmeas1 = project_traceout!(tobeteleported, σᶻ)
    zmeas2 = project_traceout!(a[3+i], σᶻ)

    if zmeas2==2 apply!(b[i], X) end
    if zmeas1==2 apply!(b[i], Z) end
end
# tobeteleported = a[2]

# apply!((tobeteleported, b[1]), sCNOT)
# apply!(tobeteleported, sHadamard)


# zmeas1 = project_traceout!(tobeteleported, σᶻ)
# zmeas2 = project_traceout!(b[1], σᶻ)

# if zmeas2==2 apply!(b[2], sX) end
# if zmeas1==2 apply!(b[2], sZ) end

order_state!(b, teleportation_order)
@info canonicalize!(stabilizerview(refstate)) == canonicalize!(stabilizerview(b.staterefs[1].state[]))