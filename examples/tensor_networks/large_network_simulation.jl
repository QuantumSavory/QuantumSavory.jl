using QuantumSavory
using ITensors

# A simulation that would be too expensive to run with exact state vectors.
# A 30 qubit state vector requires 2^30 complex numbers (~16 GB of RAM).
# With the ITensor tensor network backend, as long as the entanglement is manageable,
# the simulation can be run efficiently.

n_qubits = 30
println("Initializing a $n_qubits qubit register using ITensorRepr...")
reg = Register(n_qubits, ITensorRepr())

# Initialize qubits
for i in 1:n_qubits
    initialize!(reg[i])
end

# Apply Hadamard gates
println("Applying Hadamard gates...")
for i in 1:n_qubits
    apply!(reg[i], H)
end

# Apply CNOT gates to create a linear graph-like state
println("Applying CNOT gates to entangle qubits...")
for i in 1:n_qubits-1
    apply!((reg[i], reg[i+1]), CNOT)
end

# Check the observable on the last qubit
println("Computing expectation value of Z on the last qubit...")
val = observable(reg[n_qubits], Z)

println("Expectation value: ", val)
