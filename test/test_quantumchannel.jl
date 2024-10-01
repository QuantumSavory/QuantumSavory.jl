@testitem "Quantum Channel" tags=[:quantumchannel] begin
using ResumableFunctions
using ConcurrentSim

bell = (Z1⊗Z1 + Z2⊗Z2)/sqrt(2.0)

## Manually construct a QuantumChannel and test a simple put/take

sim = Simulation()
regA = Register(1)
regB = Register(2)
initialize!((regA[1], regB[2]), bell)
# Delay queue for quantum channel
queue = DelayQueue{Register}(sim, 10.0)
qc = QuantumChannel(queue)

@resumable function alice_node(env, qc)
    put!(qc, regA[1])
end

@resumable function bob_node(env, qc)
    @yield take!(qc, regB[1])
end

@process alice_node(sim, qc)
@process bob_node(sim, qc)

run(sim)

# the above code puts both the qubits of the state in the same register
sref = regB.staterefs[1]
@test sref.registers[1] == sref.registers[2]
@test !isassigned(regA, 1)

## Test with the second constructor

regA = Register(1)
regB = Register(2)
initialize!((regA[1], regB[2]), bell)
sim = Simulation()
qc = QuantumChannel(sim, 10.0)
@resumable function alice_node(env, qc)
    put!(qc, regA[1])
end
@resumable function bob_node(env, qc)
    @yield take!(qc, regB[1])
end
@process alice_node(sim, qc)
@process bob_node(sim, qc)
run(sim)
sref = regB.staterefs[1]
@test sref.registers[1] == sref.registers[2]
@test !isassigned(regA, 1)

## Test with T1Decay

regA = Register(1)
regB = Register(2)
initialize!((regA[1], regB[2]), bell)
sim = Simulation()
qc = QuantumChannel(sim, 10.0, T1Decay(0.1))
@resumable function alice_node(env, qc)
    put!(qc, regA[1])
end
@resumable function bob_node(env, qc)
    @yield take!(qc, regB[1])
end
@process alice_node(sim, qc)
@process bob_node(sim, qc)
run(sim)

# compare against a stationary qubit experiencing the same T1 decay
reg = Register([Qubit(), Qubit()], [T1Decay(0.1), nothing])
initialize!(reg[1:2], bell)
uptotime!(reg[1], 10.0)

@test observable(reg[1:2], projector(bell)) ≈ observable(regB[1:2], projector(bell))

## Test with T2Dephasing

regA = Register(2)
regB = Register(2)
initialize!((regA[1], regB[2]), bell)
sim = Simulation()
qc = QuantumChannel(sim, 10.0, T2Dephasing(0.1))
@resumable function alice_node(env, qc)
    put!(qc, regA[1])
end
@resumable function bob_node(env, qc)
    @yield take!(qc, regB[1])
end
@process alice_node(sim, qc)
@process bob_node(sim, qc)
run(sim)

reg = Register([Qubit(), Qubit()], [T2Dephasing(0.1), nothing])
initialize!(reg[1:2], bell)
uptotime!(reg[1], 10.0)

@test observable(reg[1:2], projector(bell)) == observable(regB[1:2], projector(bell))

## Test for slot availability

sim = Simulation()
qc = QuantumChannel(sim, 10.0, T2Dephasing(0.1))
regC = Register(1)
initialize!(regC[1], Z1)
put!(qc, regC[1])
take!(qc, regB[1])
@test_throws "A take! operation is being performed on a QuantumChannel in order to swap the state into a Register, but the target register slot is not empty (it is already initialized)." run(sim)
end
