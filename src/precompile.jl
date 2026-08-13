using PrecompileTools

@setup_workload begin
    # Putting some things in `setup` can reduce the size of the
    # precompile file and potentially make loading faster.
    @compile_workload begin
        # all calls in this block will be precompiled, regardless of whether
        # they belong to your package or not (on Julia 1.8 and higher)

        # Register interface
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
        nsubsystems(net[i].staterefs[2]) == 1
        initialize!(net[i,3],X1, time=2.0)
        nsubsystems(net[i].staterefs[2]) == 1
        apply!([net[i,2], net[i,3]], CNOT, time=3.0)
        net[i].staterefs[2].state[] isa Operator
        nsubsystems(net[i].staterefs[2]) == 2
        i = 2
        initialize!(net[i,2], time=1.0)
        nsubsystems(net[i].staterefs[2]) == 1
        initialize!(net[i,3],X1, time=2.0)
        nsubsystems(net[i].staterefs[2]) == 1
        apply!([net[i,2], net[i,3]], CNOT, time=3.0)
        net[i].staterefs[2].state[] isa MixedDestabilizer
        nsubsystems(net[i].staterefs[2]) == 2
        i = 3
        initialize!(net[i,2], time=1.0)
        nsubsystems(net[i].staterefs[2]) == 1
        initialize!(net[i,3],X1, time=2.0)
        nsubsystems(net[i].staterefs[2]) == 1
        apply!([net[i,2], net[i,3]], CNOT, time=3.0)
        net[i].staterefs[2].state[] isa MCKet
        nsubsystems(net[i].staterefs[2]) == 2

        # Symbolics and state expression
        state = 1im*X2⊗Z1+2*Y1⊗(Z2+X2)+StabilizerState("XZ YY")
        express(state)
        express(state)
        state = 1im*X1⊗Z2+2*Y2⊗(Z1+X1)+StabilizerState("YX ZZ")
        state = SProjector(state)+2*X⊗(Z+Y)/3im
        state = state+MixedState(basis(state))
        express(state)
        express(state)
        state = StabilizerState("ZZ XX")
        state = SProjector(state)*0.5 + 0.5*MixedState(state)
        state2 = deepcopy(state)
        express(state2)
        express(state2)
        express(state2, CliffordRepr())
        express(state2, CliffordRepr())
    end
end

@setup_workload let
    # Default Bell-pair construction and observable
    @compile_workload begin
        bell = (Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2)
        bellreg = Register(2)
        initialize!(bellreg[1:2], bell)
        @assert observable(bellreg[1:2], SProjector(bell)) ≈ 1
    end
end

@setup_workload let
    rng = Random.default_rng()
    saved_rng = copy(rng)
    try
        measurement_reg = Register(2)
        measurement_basis = (Z1, Z2)
        measurement_bell = (Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2)
        initialize!(measurement_reg[1:2], measurement_bell)

        Random.seed!(rng, 0x5153)
        @compile_workload begin
            measurement_outcome = project_traceout!(measurement_reg[1], Z)
            @assert observable(
                measurement_reg[2], SProjector(measurement_basis[measurement_outcome])
            ) ≈ 1
            partner_outcome = project_traceout!(measurement_reg[2], Z)
            @assert measurement_outcome == partner_outcome
            @assert !isassigned(measurement_reg, 1) && !isassigned(measurement_reg, 2)
        end
    finally
        copy!(rng, saved_rng)
    end
end

@setup_workload let
    # ProtocolZoo entanglement generation
    rng = Random.default_rng()
    saved_rng = copy(rng)
    try
        Random.seed!(rng, 0x5156)
        saved_glcnt = glcnt[]
        try
            @compile_workload begin
                network = RegisterNet([Register(1), Register(1)])
                simulation = get_time_tracker(network)
                protocol = ProtocolZoo.EntanglerProt(
                    simulation,
                    network,
                    1,
                    2;
                    chooseslotA=1,
                    chooseslotB=1,
                    success_prob=1.0,
                    rounds=1,
                )
                ConcurrentSim.@process protocol()
                ConcurrentSim.run(simulation, 1.0)
                fidelity = real(observable(
                    (network[1][1], network[2][1]),
                    SProjector((Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2)),
                ))
                @assert isapprox(fidelity, 1; atol=1e-12)
            end
        finally
            glcnt[] = saved_glcnt
        end
    finally
        copy!(rng, saved_rng)
    end
end

@setup_workload let
    # Quantum transport
    @compile_workload begin
        network = RegisterNet([Register(1), Register(1)]; quantum_delay=0.25)
        simulation = get_time_tracker(network)
        initialize!(network[1][1], X1)
        quantum_channel = qchannel(network, 1 => 2)
        put!(quantum_channel, network[1][1])
        take!(quantum_channel, network[2][1])
        ConcurrentSim.run(simulation, 1.0)
        @assert !isassigned(network[1], 1)
        @assert isassigned(network[2], 1)
        expectation = real(observable(network[2][1], X))
        @assert isapprox(expectation, 1; atol=1e-12)
    end
end

@setup_workload let
    # Clifford register operations
    rng = Random.default_rng()
    saved_rng = copy(rng)
    try
        Random.seed!(rng, 0x5154)
        @compile_workload begin
            register = Register(2, CliffordRepr())
            initialize!(register[1:2], StabilizerState("XX ZZ"))
            apply!(register[1], H)
            apply!(register[1], H)
            @assert isapprox(real(observable(register[1:2], Z ⊗ Z)), 1; atol=1e-12)
            first_outcome = project_traceout!(register[1], Z)
            partner_fidelity = real(observable(
                register[2],
                SProjector((Z1, Z2)[first_outcome]),
            ))
            second_outcome = project_traceout!(register[2], Z)
            @assert first_outcome == second_outcome
            @assert isapprox(partner_fidelity, 1; atol=1e-12)
            @assert !isassigned(register, 1) && !isassigned(register, 2)
        end
    finally
        copy!(rng, saved_rng)
    end
end
