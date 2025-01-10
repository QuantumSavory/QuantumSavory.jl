using QuantumSavory
using QuantumSavory.CircuitZoo

@info express(FockState(0, FockBasis(1))⊗ FockState(1, FockBasis(1)) ⊗ FockState(1, FockBasis(1)))
@info express(FockState(1, FockBasis(1))⊗ FockState(1, FockBasis(1)) ⊗ FockState(0, FockBasis(1)))
@info express(FockState(1, FockBasis(1))⊗ FockState(0, FockBasis(1)) ⊗ FockState(1, FockBasis(1)))


# teleportation of graph state qubit
bell = StabilizerState("ZZ XX")

a = Register(3) # switch
bs = [Register(2) for _ in range(1,3)] # bell pair


# Create a graph state
initialize!((a[1],a[2],a[3]), X1⊗X1⊗X1)  # Initialize a in |+⟩ state
apply!((a[1],a[2]), ZCZ)  # Create a graph state
apply!((a[2],a[3]), ZCZ)

refstate = copy(a.staterefs[1].state[])
@info a.staterefs[2].state[]

# Initialize 3 bell pairs and teleport qubits
for i in range(1,3)
    b = bs[i]
    initialize!((b[1], b[2]), bell) 

    # Teleportation protocol
    order = [3,1,2]
    tobeteleported = a[order[i]]
    apply!((tobeteleported, b[1]), CNOT)
    apply!(tobeteleported, H)

    zmeas1 = project_traceout!(tobeteleported, σᶻ)
    zmeas2 = project_traceout!(b[1], σᶻ)

    if zmeas2==2 apply!(b[2], X) end
    if zmeas1==2 apply!(b[2], Z) end
end 

# apply!((a[4], b[2]), CNOT)
# apply!((b[2], a[4]), CNOT)
# apply!((a[4], b[2]), CNOT)

#@info a.staterefs[i].state[]
for b in bs
    @info b.staterefs[2].state[]
    @info abs(dagger(b.staterefs[2].state[])*refstate)^2
end

