@testitem "Noninstant and Backgrounds Qubit" tags=[:noninstant_and_backgrounds_qubit] begin
    using QuantumSavory: NonInstantGate

    ##
    # Time of application and gate durations
    reg = Register([Qubit(),Qubit()])
    initialize!(reg[1])
    initialize!(reg[2])
    uptotime!(reg[1],0.2)
    uptotime!(reg[1],0.2)
    @test_throws ErrorException uptotime!(reg[1],0.1)
    apply!(reg[1], H; time=0.3)
    apply!(reg[1], NonInstantGate(H,0.1); time=0.4)
    apply!([reg[1],reg[2]], NonInstantGate(CNOT, 0.1))
    @test_throws ErrorException uptotime!(reg[1],0.55)
    @test_throws ErrorException apply!(reg[1], H; time=0.55)

    ##
    # Kraus vs Lindblad
    function kraus_lindblad_test(background,initstate)
        reg = Register([Qubit(),Qubit()],[background, background])
        initialize!(reg[1], initstate)
        initialize!(reg[2], initstate)
        uptotime!(reg[1],0.2)
        uptotime!(reg[2],0.1)
        uptotime!(reg[2],0.2)
        # Test that Kraus weights are calculated correctly
        @test reg.staterefs[1].state[] ≈ reg.staterefs[2].state[]

        regb = Register([Qubit(),Qubit()],[background, background])
        initialize!(regb[1], initstate)
        initialize!(regb[2], initstate)
        subsystemcompose(regb[1],regb[2])
        uptotime!(regb[1],0.2)
        uptotime!(regb[2],0.1)
        uptotime!(regb[2],0.2)
        @test reg.staterefs[1].state[]⊗reg.staterefs[2].state[] ≈ regb.staterefs[2].state[]

        apply!(reg[1],ConstantHamiltonianEvolution(IdentityOp(X1),0.1),time=0.3)
        uptotime!(reg[2],0.4)
        @test reg.staterefs[1].state[] ≈ reg.staterefs[2].state[]

        apply!(regb[1],ConstantHamiltonianEvolution(IdentityOp(X1),0.1),time=0.3)
        uptotime!(regb[2],0.4)
        @test reg.staterefs[1].state[]⊗reg.staterefs[2].state[] ≈ regb.staterefs[2].state[]
    end

    kraus_lindblad_test(T1Decay(1.0),Z1)
    kraus_lindblad_test(T1Decay(1.0),Z2)
    kraus_lindblad_test(T1Decay(1.0),X1)
    kraus_lindblad_test(T1Decay(1.0),X2)
    kraus_lindblad_test(T2Dephasing(1.0),Z1)
    kraus_lindblad_test(T2Dephasing(1.0),Z2)
    kraus_lindblad_test(T2Dephasing(1.0),X1)
    kraus_lindblad_test(T2Dephasing(1.0),X2)
end
