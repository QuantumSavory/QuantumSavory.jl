SUITE["register"] = BenchmarkGroup(["register"])

function benchmark_register_traits()
    [Qubit(), Qubit(), Qubit()]
end

function benchmark_register_backgrounds()
    [T2Dephasing(1.0), T2Dephasing(1.0), T2Dephasing(1.0)]
end

function benchmark_register_clifford_reprs()
    [QuantumOpticsRepr(), CliffordRepr(), CliffordRepr()]
end

function benchmark_register_quantummc_reprs()
    [QuantumOpticsRepr(), QuantumMCRepr(), QuantumMCRepr()]
end

function create_default_register()
    Register(benchmark_register_traits())
end

function create_clifford_register()
    Register(benchmark_register_traits(), benchmark_register_clifford_reprs())
end

function create_quantummc_register()
    Register(benchmark_register_traits(), benchmark_register_quantummc_reprs())
end

function create_default_register_with_backgrounds()
    Register(benchmark_register_traits(), benchmark_register_backgrounds())
end

function create_clifford_register_with_backgrounds()
    Register(benchmark_register_traits(), benchmark_register_clifford_reprs(), benchmark_register_backgrounds())
end

function create_quantummc_register_with_backgrounds()
    Register(benchmark_register_traits(), benchmark_register_quantummc_reprs(), benchmark_register_backgrounds())
end

function create_mixed_register_net()
    RegisterNet([
        create_default_register(),
        create_clifford_register(),
        create_quantummc_register(),
    ])
end

function create_mixed_register_net_with_backgrounds()
    RegisterNet([
        create_default_register_with_backgrounds(),
        create_clifford_register_with_backgrounds(),
        create_quantummc_register_with_backgrounds(),
    ])
end

function initialize_default_pair()
    reg = create_default_register()
    initialize!(reg[2])
    @assert nsubsystems(reg.staterefs[2]) == 1
    initialize!(reg[3], X1)
    @assert nsubsystems(reg.staterefs[2]) == 1
    apply!([reg[2], reg[3]], CNOT)
    @assert reg.staterefs[2].state[] isa Ket
    @assert nsubsystems(reg.staterefs[2]) == 2
    reg
end

function initialize_clifford_pair()
    reg = create_clifford_register()
    initialize!(reg[2])
    @assert nsubsystems(reg.staterefs[2]) == 1
    initialize!(reg[3], X1)
    @assert nsubsystems(reg.staterefs[2]) == 1
    apply!([reg[2], reg[3]], CNOT)
    @assert reg.staterefs[2].state[] isa MixedDestabilizer
    @assert nsubsystems(reg.staterefs[2]) == 2
    reg
end

function initialize_quantummc_pair()
    reg = create_quantummc_register()
    initialize!(reg[2])
    @assert nsubsystems(reg.staterefs[2]) == 1
    initialize!(reg[3], X1)
    @assert nsubsystems(reg.staterefs[2]) == 1
    apply!([reg[2], reg[3]], CNOT)
    @assert reg.staterefs[2].state[] isa Ket
    @assert nsubsystems(reg.staterefs[2]) == 2
    reg
end

function initialize_default_pair_with_backgrounds()
    reg = create_default_register_with_backgrounds()
    initialize!(reg[2], time=1.0)
    @assert nsubsystems(reg.staterefs[2]) == 1
    initialize!(reg[3], X1, time=2.0)
    @assert nsubsystems(reg.staterefs[2]) == 1
    apply!([reg[2], reg[3]], CNOT, time=3.0)
    @assert reg.staterefs[2].state[] isa Operator
    @assert nsubsystems(reg.staterefs[2]) == 2
    reg
end

function initialize_clifford_pair_with_backgrounds()
    reg = create_clifford_register_with_backgrounds()
    initialize!(reg[2], time=1.0)
    @assert nsubsystems(reg.staterefs[2]) == 1
    initialize!(reg[3], X1, time=2.0)
    @assert nsubsystems(reg.staterefs[2]) == 1
    apply!([reg[2], reg[3]], CNOT, time=3.0)
    @assert reg.staterefs[2].state[] isa MixedDestabilizer
    @assert nsubsystems(reg.staterefs[2]) == 2
    reg
end

function initialize_quantummc_pair_with_backgrounds()
    reg = create_quantummc_register_with_backgrounds()
    initialize!(reg[2], time=1.0)
    @assert nsubsystems(reg.staterefs[2]) == 1
    initialize!(reg[3], X1, time=2.0)
    @assert nsubsystems(reg.staterefs[2]) == 1
    apply!([reg[2], reg[3]], CNOT, time=3.0)
    @assert nsubsystems(reg.staterefs[2]) == 2
    reg
end

SUITE["register"]["creation"] = BenchmarkGroup(["creation"])
SUITE["register"]["creation"]["default"] = @benchmarkable create_default_register()
SUITE["register"]["creation"]["clifford"] = @benchmarkable create_clifford_register()
SUITE["register"]["creation"]["quantummc"] = @benchmarkable create_quantummc_register()
SUITE["register"]["creation"]["default_backgrounds"] = @benchmarkable create_default_register_with_backgrounds()
SUITE["register"]["creation"]["clifford_backgrounds"] = @benchmarkable create_clifford_register_with_backgrounds()
SUITE["register"]["creation"]["quantummc_backgrounds"] = @benchmarkable create_quantummc_register_with_backgrounds()

SUITE["register"]["net_creation"] = BenchmarkGroup(["net_creation"])
SUITE["register"]["net_creation"]["mixed_representations"] = @benchmarkable create_mixed_register_net()
SUITE["register"]["net_creation"]["mixed_representations_backgrounds"] = @benchmarkable create_mixed_register_net_with_backgrounds()

SUITE["register"]["initialization"] = BenchmarkGroup(["initialization"])
SUITE["register"]["initialization"]["default_pair"] = @benchmarkable initialize_default_pair() evals=1
SUITE["register"]["initialization"]["clifford_pair"] = @benchmarkable initialize_clifford_pair() evals=1
SUITE["register"]["initialization"]["quantummc_pair"] = @benchmarkable initialize_quantummc_pair() evals=1
SUITE["register"]["initialization"]["default_pair_backgrounds"] = @benchmarkable initialize_default_pair_with_backgrounds() evals=1
SUITE["register"]["initialization"]["clifford_pair_backgrounds"] = @benchmarkable initialize_clifford_pair_with_backgrounds() evals=1
SUITE["register"]["initialization"]["quantummc_pair_backgrounds"] = @benchmarkable initialize_quantummc_pair_with_backgrounds() evals=1

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
