using SnoopPrecompile

@precompile_setup begin
    # Putting some things in `setup` can reduce the size of the
    # precompile file and potentially make loading faster.
    @precompile_all_calls begin
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
