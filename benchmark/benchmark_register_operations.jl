module benchmark_register_operations


export create_register_net, create_register_net_with_backgrounds, initialize_register_net, initialize_register_net_with_backgrounds


using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumSavory: tag_types
using QuantumOpticsBase: Ket, Operator
using QuantumClifford: MixedDestabilizer, ghz
using BenchmarkTools


# Variables



traits = [Qubit(), Qubit(), Qubit()]
qc_reprs = [QuantumOpticsRepr(), CliffordRepr(), CliffordRepr()]

# Function to create a RegisterNet based on specified parameters with no backgrounds
function create_register_net()
    reg1 = Register(traits)
    reg2 = Register(traits, qc_reprs)
    qmc_reprs = [QuantumOpticsRepr(), QuantumMCRepr(), QuantumMCRepr()]
    reg3 = Register(traits, qmc_reprs)
    return RegisterNet([reg1, reg2, reg3])
end

# Function to create a RegisterNet based on specified parameters with backgrounds
function create_register_net_with_backgrounds()
    backgrounds = [T2Dephasing(1.0), T2Dephasing(1.0), T2Dephasing(1.0)]
    reg1 = Register(traits, backgrounds)
    reg2 = Register(traits, qc_reprs, backgrounds)
    qmc_reprs = [QuantumOpticsRepr(), QuantumMCRepr(), QuantumMCRepr()]
    reg3 = Register(traits, qmc_reprs, backgrounds)
    return RegisterNet([reg1, reg2, reg3])
end



# Function to Initialize a RegisterNet without backgrounds
function initialize_register_net()
    net = create_register_net()
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
end

# Function to initialize a RegisterNet with backgrounds
function initialize_register_net_with_backgrounds()
    net = create_register_net_with_backgrounds()
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


end