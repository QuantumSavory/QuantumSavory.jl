SUITE["register"] = BenchmarkGroup(["register"])

register_traits_3() = [Qubit(), Qubit(), Qubit()]
register_traits_64() = [Qubit() for _ in 1:64]

register_backgrounds_3() = [T2Dephasing(1.0), T2Dephasing(1.0), T2Dephasing(1.0)]
register_backgrounds_64() = [T2Dephasing(1.0) for _ in 1:64]

register_clifford_reprs_3() = [QuantumOpticsRepr(), CliffordRepr(), CliffordRepr()]
register_quantummc_reprs_3() = [QuantumOpticsRepr(), QuantumMCRepr(), QuantumMCRepr()]

register_qubits_3(traits=register_traits_3()) = Register(traits)
register_qubits_64(traits=register_traits_64()) = Register(traits)
register_clifford_mixed_3(traits=register_traits_3(), reprs=register_clifford_reprs_3()) = Register(traits, reprs)
register_quantummc_mixed_3(traits=register_traits_3(), reprs=register_quantummc_reprs_3()) = Register(traits, reprs)

register_qubits_with_backgrounds_3(traits=register_traits_3(), backgrounds=register_backgrounds_3()) = Register(traits, backgrounds)
register_qubits_with_backgrounds_64(traits=register_traits_64(), backgrounds=register_backgrounds_64()) = Register(traits, backgrounds)
register_clifford_with_backgrounds_3(traits=register_traits_3(), reprs=register_clifford_reprs_3(), backgrounds=register_backgrounds_3()) = Register(traits, reprs, backgrounds)
register_quantummc_with_backgrounds_3(traits=register_traits_3(), reprs=register_quantummc_reprs_3(), backgrounds=register_backgrounds_3()) = Register(traits, reprs, backgrounds)

function register_net_mixed_3_nodes()
    RegisterNet([register_qubits_3(), register_clifford_mixed_3(), register_quantummc_mixed_3()])
end

function register_net_chain_64_nodes()
    RegisterNet([Register(3) for _ in 1:64])
end

function prepare_qubits_pair_register()
    reg = register_qubits_3()
    initialize!(reg[2])
    initialize!(reg[3], X1)
    reg
end

function prepare_clifford_pair_register()
    reg = register_clifford_mixed_3()
    initialize!(reg[2])
    initialize!(reg[3], X1)
    reg
end

function prepare_quantummc_pair_register()
    reg = register_quantummc_mixed_3()
    initialize!(reg[2])
    initialize!(reg[3], X1)
    reg
end

function prepare_qubits_pair_register_with_backgrounds()
    reg = register_qubits_with_backgrounds_3()
    initialize!(reg[2], time=1.0)
    initialize!(reg[3], X1, time=2.0)
    reg
end

function prepare_clifford_pair_register_with_backgrounds()
    reg = register_clifford_with_backgrounds_3()
    initialize!(reg[2], time=1.0)
    initialize!(reg[3], X1, time=2.0)
    reg
end

function prepare_quantummc_pair_register_with_backgrounds()
    reg = register_quantummc_with_backgrounds_3()
    initialize!(reg[2], time=1.0)
    initialize!(reg[3], X1, time=2.0)
    reg
end

apply_cnot_pair!(reg) = apply!([reg[2], reg[3]], CNOT)
apply_cnot_pair_with_backgrounds!(reg) = apply!([reg[2], reg[3]], CNOT, time=3.0)

SUITE["register"]["creation"] = BenchmarkGroup(["creation"])
SUITE["register"]["creation"]["qubits_3"] = @benchmarkable register_qubits_3(traits) setup=(traits = register_traits_3())
SUITE["register"]["creation"]["qubits_64"] = @benchmarkable register_qubits_64(traits) setup=(traits = register_traits_64())
SUITE["register"]["creation"]["mixed_clifford_3"] = @benchmarkable register_clifford_mixed_3(traits, reprs) setup=(traits = register_traits_3(); reprs = register_clifford_reprs_3())
SUITE["register"]["creation"]["mixed_quantummc_3"] = @benchmarkable register_quantummc_mixed_3(traits, reprs) setup=(traits = register_traits_3(); reprs = register_quantummc_reprs_3())
SUITE["register"]["creation"]["backgrounds_3"] = @benchmarkable register_qubits_with_backgrounds_3(traits, backgrounds) setup=(traits = register_traits_3(); backgrounds = register_backgrounds_3())
SUITE["register"]["creation"]["backgrounds_64"] = @benchmarkable register_qubits_with_backgrounds_64(traits, backgrounds) setup=(traits = register_traits_64(); backgrounds = register_backgrounds_64())
SUITE["register"]["creation"]["mixed_clifford_backgrounds_3"] = @benchmarkable register_clifford_with_backgrounds_3(traits, reprs, backgrounds) setup=(traits = register_traits_3(); reprs = register_clifford_reprs_3(); backgrounds = register_backgrounds_3())
SUITE["register"]["creation"]["mixed_quantummc_backgrounds_3"] = @benchmarkable register_quantummc_with_backgrounds_3(traits, reprs, backgrounds) setup=(traits = register_traits_3(); reprs = register_quantummc_reprs_3(); backgrounds = register_backgrounds_3())

# RegisterNet construction has separate small and larger cases so graph and
# channel setup regressions are visible without having to run protocol examples.
SUITE["register"]["network_creation"] = BenchmarkGroup(["network_creation"])
SUITE["register"]["network_creation"]["mixed_3_nodes"] = @benchmarkable RegisterNet(registers) setup=(registers = [register_qubits_3(), register_clifford_mixed_3(), register_quantummc_mixed_3()]) evals=1
SUITE["register"]["network_creation"]["chain_64_nodes"] = @benchmarkable RegisterNet(registers) setup=(registers = [Register(3) for _ in 1:64]) evals=1

# Mutating register operations use a fresh setup object for every evaluation.
SUITE["register"]["initialize"] = BenchmarkGroup(["initialize"])
SUITE["register"]["initialize"]["qubits_zero"] = @benchmarkable initialize!(reg[2]) setup=(reg = register_qubits_3()) evals=1
SUITE["register"]["initialize"]["qubits_x_state"] = @benchmarkable initialize!(reg[2], X1) setup=(reg = register_qubits_3()) evals=1
SUITE["register"]["initialize"]["clifford_zero"] = @benchmarkable initialize!(reg[2]) setup=(reg = register_clifford_mixed_3()) evals=1
SUITE["register"]["initialize"]["quantummc_zero"] = @benchmarkable initialize!(reg[2]) setup=(reg = register_quantummc_mixed_3()) evals=1
SUITE["register"]["initialize"]["backgrounds_zero"] = @benchmarkable initialize!(reg[2], time=1.0) setup=(reg = register_qubits_with_backgrounds_3()) evals=1
SUITE["register"]["initialize"]["clifford_backgrounds_zero"] = @benchmarkable initialize!(reg[2], time=1.0) setup=(reg = register_clifford_with_backgrounds_3()) evals=1
SUITE["register"]["initialize"]["quantummc_backgrounds_zero"] = @benchmarkable initialize!(reg[2], time=1.0) setup=(reg = register_quantummc_with_backgrounds_3()) evals=1

SUITE["register"]["apply"] = BenchmarkGroup(["apply"])
SUITE["register"]["apply"]["cnot_qubits"] = @benchmarkable apply_cnot_pair!(reg) setup=(reg = prepare_qubits_pair_register()) evals=1
SUITE["register"]["apply"]["cnot_clifford"] = @benchmarkable apply_cnot_pair!(reg) setup=(reg = prepare_clifford_pair_register()) evals=1
SUITE["register"]["apply"]["cnot_quantummc"] = @benchmarkable apply_cnot_pair!(reg) setup=(reg = prepare_quantummc_pair_register()) evals=1
SUITE["register"]["apply"]["cnot_backgrounds"] = @benchmarkable apply_cnot_pair_with_backgrounds!(reg) setup=(reg = prepare_qubits_pair_register_with_backgrounds()) evals=1
SUITE["register"]["apply"]["cnot_clifford_backgrounds"] = @benchmarkable apply_cnot_pair_with_backgrounds!(reg) setup=(reg = prepare_clifford_pair_register_with_backgrounds()) evals=1
SUITE["register"]["apply"]["cnot_quantummc_backgrounds"] = @benchmarkable apply_cnot_pair_with_backgrounds!(reg) setup=(reg = prepare_quantummc_pair_register_with_backgrounds()) evals=1

SUITE["register"]["creation_and_initialization"] = BenchmarkGroup(["creation_and_initialization"])
function register_creation_and_initialization()
    traits = [Qubit(), Qubit(), Qubit()]
    reg1 = Register(traits)
    qc_repr = [QuantumOpticsRepr(), CliffordRepr(), CliffordRepr()]
    reg2 = Register(traits, qc_repr)
    qmc_repr = [QuantumOpticsRepr(), QuantumMCRepr(), QuantumMCRepr()]
    reg3 = Register(traits, qmc_repr)
    net = RegisterNet([reg1, reg2, reg3])

    i = 1
    initialize!(net[i,2])
    @assert nsubsystems(net[i].staterefs[2]) == 1
    initialize!(net[i,3],X1)
    @assert nsubsystems(net[i].staterefs[2]) == 1
    apply!([net[i,2], net[i,3]], CNOT)
    @assert net[i].staterefs[2].state[] isa Ket
    @assert nsubsystems(net[i].staterefs[2]) == 2

    i = 2
    initialize!(net[i,2])
    @assert nsubsystems(net[i].staterefs[2]) == 1
    initialize!(net[i,3],X1)
    @assert nsubsystems(net[i].staterefs[2]) == 1
    apply!([net[i,2], net[i,3]], CNOT)
    @assert net[i].staterefs[2].state[] isa MixedDestabilizer
    @assert nsubsystems(net[i].staterefs[2]) == 2

    i = 3
    initialize!(net[i,2])
    @assert nsubsystems(net[i].staterefs[2]) == 1
    initialize!(net[i,3],X1)
    @assert nsubsystems(net[i].staterefs[2]) == 1
    apply!([net[i,2], net[i,3]], CNOT)
    @assert net[i].staterefs[2].state[] isa Ket
    @assert nsubsystems(net[i].staterefs[2]) == 2

    ##
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
    @assert nsubsystems(net[i].staterefs[2]) == 1
    initialize!(net[i,3],X1, time=2.0)
    @assert nsubsystems(net[i].staterefs[2]) == 1
    apply!([net[i,2], net[i,3]], CNOT, time=3.0)
    @assert net[i].staterefs[2].state[] isa Operator
    @assert nsubsystems(net[i].staterefs[2]) == 2

    i = 2
    initialize!(net[i,2], time=1.0)
    @assert nsubsystems(net[i].staterefs[2]) == 1
    initialize!(net[i,3],X1, time=2.0)
    @assert nsubsystems(net[i].staterefs[2]) == 1
    apply!([net[i,2], net[i,3]], CNOT, time=3.0)
    @assert net[i].staterefs[2].state[] isa MixedDestabilizer
    @assert nsubsystems(net[i].staterefs[2]) == 2

    i = 3
    initialize!(net[i,2], time=1.0)
    @assert nsubsystems(net[i].staterefs[2]) == 1
    initialize!(net[i,3],X1, time=2.0)
    @assert nsubsystems(net[i].staterefs[2]) == 1
    apply!([net[i,2], net[i,3]], CNOT, time=3.0)
    @assert nsubsystems(net[i].staterefs[2]) == 2
end
SUITE["register"]["creation_and_initialization"]["from_tests"] = @benchmarkable register_creation_and_initialization()
