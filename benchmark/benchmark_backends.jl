SUITE["backends"] = BenchmarkGroup(["backends"])

# Register operations with different backends
for (name, repr_type) in [
    ("clifford", CliffordRepr()),
    ("quantumoptics", QuantumOpticsRepr()),
    ("quantummc", QuantumMCRepr()),
]
    SUITE["backends"]["initialize_$name"] = @benchmarkable begin
        reg = Register([Qubit()], [$repr_type])
        initialize!(reg[1], Z1)
    end

    SUITE["backends"]["apply_gate_$name"] = @benchmarkable begin
        reg = Register([Qubit(), Qubit()], [$repr_type, $repr_type])
        initialize!(reg[1], Z1)
        initialize!(reg[2], Z1)
        apply!([reg[1], reg[2]], CNOT)
    end

    SUITE["backends"]["measure_$name"] = @benchmarkable begin
        reg = Register([Qubit()], [$repr_type])
        initialize!(reg[1], (Z1 + X1)/√2)
        measure!(reg[1], Z1)
    end
end

# Multi-backend register net
function multi_backend_net()
    traits = [Qubit(), Qubit(), Qubit()]
    reprs = [CliffordRepr(), QuantumOpticsRepr(), QuantumMCRepr()]
    reg1 = Register(traits, reprs)
    reg2 = Register(traits, [QuantumOpticsRepr(), CliffordRepr(), QuantumMCRepr()])
    net = RegisterNet([reg1, reg2])
    initialize!(net[1,1], Z1)
    initialize!(net[1,2], (Z1 + X1)/√2)
    initialize!(net[2,3], Z1)
    apply!([net[1,1], net[2,3]], CNOT)
end
SUITE["backends"]["multi_backend_net"] = @benchmarkable multi_backend_net()

# GabsRepr backend (Gaussian)
SUITE["backends"]["gaussian"] = BenchmarkGroup(["gaussian"])
SUITE["backends"]["gaussian"]["initialize"] = @benchmarkable begin
    reg = Register([Qumode()], [GabsRepr(QuadBlockBasis)])
    initialize!(reg[1], CoherentState(1.0))
end
SUITE["backends"]["gaussian"]["displace"] = @benchmarkable begin
    reg = Register([Qumode()], [GabsRepr(QuadBlockBasis)])
    initialize!(reg[1], CoherentState(0.0))
    apply!(reg[1], Displace(1.0))
end
