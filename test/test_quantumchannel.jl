using QuantumSavory
using ResumableFunctions
using ConcurrentSim
using Test

bell = (Z1⊗Z1 + Z2⊗Z2)/sqrt(2.0)
regA = Register(2)
regB = Register(2)
initialize!((regA[1], regB[2]), bell)

sim = Simulation()

# Delay queue for quantum channel 
queue = DelayQueue{Register}(sim, 10.0)

qc = QuantumChannel(queue)

@resumable function alice_node(env, qc)
    put!(qc, regA[1])
end

@resumable function bob_node(env, qc)
    @yield @process take!(env, qc, regB[1])
end

@process alice_node(sim, qc)
@process bob_node(sim, qc)

run(sim)

sref = regB.staterefs[1]

# the above code puts both the qubits of the state in the same register
@test sref.registers[1] == sref.registers[2]



bell = (Z1⊗Z1 + Z2⊗Z2)/sqrt(2.0)
regA = Register(2)
regB = Register(2)
initialize!((regA[1], regB[2]), bell)

sim = Simulation()

qc = QuantumChannel(sim, 10.0)

@resumable function alice_node(env, qc)
    put!(qc, regA[1])
end

@resumable function bob_node(env, qc)
    @yield @process take!(env, qc, regB[1])
end

@process alice_node(sim, qc)
@process bob_node(sim, qc)

run(sim)

sref = regB.staterefs[1]

@test sref.registers[1] == sref.registers[2]