using Test
using QuantumSavory
using QuantumOpticsBase: Ket, Operator
using QuantumClifford: MixedDestabilizer

# no backgrounds
traits = [Qubit(), Qubit(), Qubit()]
reg1 = Register(traits)
qc_repr = [QuantumOpticsRepr(), CliffordRepr(), CliffordRepr()]
reg2 = Register(traits, qc_repr)
qmc_repr = [QuantumOpticsRepr(), QuantumMCRepr(), QuantumMCRepr()]
reg3 = Register(traits, qmc_repr)
net = RegisterNet([reg1, reg2, reg3])

i = 1
initialize!(net[i,2])
@test nsubsystems(net[i].staterefs[2]) == 1
initialize!(net[i,3],X1)
@test nsubsystems(net[i].staterefs[2]) == 1
apply!([net[i,2], net[i,3]], CNOT)
@test net[i].staterefs[2].state[] isa Ket
@test nsubsystems(net[i].staterefs[2]) == 2

i = 2
initialize!(net[i,2])
@test nsubsystems(net[i].staterefs[2]) == 1
initialize!(net[i,3],X1)
@test nsubsystems(net[i].staterefs[2]) == 1
apply!([net[i,2], net[i,3]], CNOT)
@test net[i].staterefs[2].state[] isa MixedDestabilizer
@test nsubsystems(net[i].staterefs[2]) == 2

i = 3
initialize!(net[i,2])
@test nsubsystems(net[i].staterefs[2]) == 1
initialize!(net[i,3],X1)
@test nsubsystems(net[i].staterefs[2]) == 1
apply!([net[i,2], net[i,3]], CNOT)
@test net[i].staterefs[2].state[] isa Ket
@test nsubsystems(net[i].staterefs[2]) == 2

# with backgrounds
traits = [Qubit(), Qubit(), Qubit()]
backgrounds = [T2Dephasing(1.0),T2Dephasing(1.0),T2Dephasing(1.0)]
reg1 = Register(traits, backgrounds)
qc_repr = [QuantumOpticsRepr(), CliffordRepr(), CliffordRepr()]
reg2 = Register(traits, qc_repr, backgrounds)
qmc_repr = [QuantumOpticsRepr(), QuantumMCRepr(), QuantumMCRepr()]
reg3 = Register(traits, qmc_repr, backgrounds)
net = RegisterNet([reg1, reg2, reg3])

i = 1
initialize!(net[i,2], time=1.0)
@test nsubsystems(net[i].staterefs[2]) == 1
initialize!(net[i,3],X1, time=2.0)
@test nsubsystems(net[i].staterefs[2]) == 1
apply!([net[i,2], net[i,3]], CNOT, time=3.0)
@test net[i].staterefs[2].state[] isa Operator
@test nsubsystems(net[i].staterefs[2]) == 2

i = 2
initialize!(net[i,2], time=1.0)
@test nsubsystems(net[i].staterefs[2]) == 1
initialize!(net[i,3],X1, time=2.0)
@test nsubsystems(net[i].staterefs[2]) == 1
apply!([net[i,2], net[i,3]], CNOT, time=3.0)
@test net[i].staterefs[2].state[] isa MixedDestabilizer
@test nsubsystems(net[i].staterefs[2]) == 2

i = 3
initialize!(net[i,2], time=1.0)
@test nsubsystems(net[i].staterefs[2]) == 1
initialize!(net[i,3],X1, time=2.0)
@test nsubsystems(net[i].staterefs[2]) == 1
apply!([net[i,2], net[i,3]], CNOT, time=3.0)
@test_broken net[i].staterefs[2].state[] isa Ket
@test nsubsystems(net[i].staterefs[2]) == 2
