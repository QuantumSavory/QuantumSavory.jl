@testitem "Bell State Measurement" tags=[:circuitzoo_bsm] begin
using QuantumSavory.CircuitZoo: BellStateMeasurement
using Random

    for _ in 1:10
        # Randomly generate a state for Alice to send
        a = rand()
        state_to_send = √(a)*X1 + √(1-a)*X2
        # Create a Bell state
        bell = StabilizerState("XX ZZ")
        # Create registers for Alice and Bob
        regA = Register(2); 
        regB = Register(1);

        # Initialize the registers
        initialize!(regA[1], state_to_send);
        initialize!((regA[2], regB[1]), bell);

        # Execute BSM
        xmeas, zmeas = BellStateMeasurement()(regA[1], regA[2]);

        # Apply corrections on Bob's end
        if xmeas==2 apply!(regB[1], X) end
        if zmeas==2 apply!(regB[1], Z) end

        @test real(observable(regB[1], projector(state_to_send))) ≈ 1.0
        @test isnothing(regA.staterefs[1]) & isnothing(regA.staterefs[2]) 
    end
end
