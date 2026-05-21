SUITE["register"] = BenchmarkGroup(["register"])
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

SUITE["register"]["micro"] = BenchmarkGroup(["micro"])

const _traits = [Qubit(), Qubit(), Qubit()]
const _qc_repr = [QuantumOpticsRepr(), CliffordRepr(), CliffordRepr()]
const _qmc_repr = [QuantumOpticsRepr(), QuantumMCRepr(), QuantumMCRepr()]
const _backgrounds = [T2Dephasing(1.0), T2Dephasing(1.0), T2Dephasing(1.0)]

create_register_net_plain() = RegisterNet([Register(_traits), Register(_traits, _qc_repr), Register(_traits, _qmc_repr)])
create_register_net_with_backgrounds() = RegisterNet([Register(_traits, _backgrounds), Register(_traits, _qc_repr, _backgrounds), Register(_traits, _qmc_repr, _backgrounds)])

function initialize_pair_qo!()
    net = create_register_net_plain()
    initialize!(net[1,2])
    initialize!(net[1,3], X1)
    apply!([net[1,2], net[1,3]], CNOT)
    @assert net[1].staterefs[2].state[] isa Ket
    return nothing
end

function initialize_pair_qc!()
    net = create_register_net_plain()
    initialize!(net[2,2])
    initialize!(net[2,3], X1)
    apply!([net[2,2], net[2,3]], CNOT)
    @assert net[2].staterefs[2].state[] isa MixedDestabilizer
    return nothing
end

function initialize_pair_qmc!()
    net = create_register_net_plain()
    initialize!(net[3,2])
    initialize!(net[3,3], X1)
    apply!([net[3,2], net[3,3]], CNOT)
    @assert net[3].staterefs[2].state[] isa Ket
    return nothing
end

function initialize_pair_qo_background!()
    net = create_register_net_with_backgrounds()
    initialize!(net[1,2], time=1.0)
    initialize!(net[1,3], X1, time=2.0)
    apply!([net[1,2], net[1,3]], CNOT, time=3.0)
    @assert net[1].staterefs[2].state[] isa Operator
    return nothing
end

function initialize_pair_qc_background!()
    net = create_register_net_with_backgrounds()
    initialize!(net[2,2], time=1.0)
    initialize!(net[2,3], X1, time=2.0)
    apply!([net[2,2], net[2,3]], CNOT, time=3.0)
    @assert net[2].staterefs[2].state[] isa MixedDestabilizer
    return nothing
end

function initialize_pair_qmc_background!()
    net = create_register_net_with_backgrounds()
    initialize!(net[3,2], time=1.0)
    initialize!(net[3,3], X1, time=2.0)
    apply!([net[3,2], net[3,3]], CNOT, time=3.0)
    @assert nsubsystems(net[3].staterefs[2]) == 2
    return nothing
end

SUITE["register"]["micro"]["create_net_plain"] = @benchmarkable create_register_net_plain()
SUITE["register"]["micro"]["create_net_backgrounds"] = @benchmarkable create_register_net_with_backgrounds()
SUITE["register"]["micro"]["init_pair_qo"] = @benchmarkable initialize_pair_qo!()
SUITE["register"]["micro"]["init_pair_qc"] = @benchmarkable initialize_pair_qc!()
SUITE["register"]["micro"]["init_pair_qmc"] = @benchmarkable initialize_pair_qmc!()
SUITE["register"]["micro"]["init_pair_qo_background"] = @benchmarkable initialize_pair_qo_background!()
SUITE["register"]["micro"]["init_pair_qc_background"] = @benchmarkable initialize_pair_qc_background!()
SUITE["register"]["micro"]["init_pair_qmc_background"] = @benchmarkable initialize_pair_qmc_background!()
