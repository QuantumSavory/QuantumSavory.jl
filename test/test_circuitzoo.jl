using Test
using QuantumSavory
using QuantumSavory.CircuitZoo: EntanglementSwap, Purify2to1, Purify3to1, PurifyStringent, PurifyExpedient


const T2=0
const perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
const perfect_pair_dm = SProjector(perfect_pair)
const mixed_dm = MixedState(perfect_pair_dm)
noisy_pair_func(F) = F*perfect_pair_dm + (1-F)*mixed_dm

function entangled_registers(size, purity, T2=0)
    regA = Register([Qubit() for  _ in 1:size],
                    [QuantumOpticsRepr() for  _ in 1:size], 
                    [T2Dephasing(T2) for  _ in 1:size])
    regB = Register([Qubit() for  _ in 1:size],
                    [QuantumOpticsRepr() for  _ in 1:size], 
                    [T2Dephasing(T2) for  _ in 1:size])

    for i in 1:size
        initialize!((regA[i],regB[i]), noisy_pair_func(purity))
    end
    regA, regB
end

@testset "Keep Pure I Entanglement" begin
    @testset "Purify2to1" begin
        for _ in 1:10
            regA, regB = entangled_registers(2, 1)
            purificationcircuit = Purify2to1(:X) # original single selection
            success = purificationcircuit(regA[1], regB[1], regA[2], regB[2])
            @test success == true
        end
    end

    @testset "Purify3to1" begin
        for _ in 1:10
            regA, regB = entangled_registers(3, 1)
            purificationcircuit = Purify3to1(:Y) # original double selection
            success = purificationcircuit(regA[1], regB[1], [regA[2], regA[3]], [regB[2], regB[3]])
            @test success == true
        end
    end

    @testset "PurifyStringent" begin
        for _ in 1:10
            regA, regB = entangled_registers(13, 1)
            purificationcircuit = PurifyStringent() # original single selection
            success = purificationcircuit(regA[1], regB[1], regA[2:13], regB[2:13])
            @test success == true
        end
    end

    @testset "PurifyExpedient" begin
        for _ in 1:10
            regA, regB = entangled_registers(11, 1)
            purificationcircuit = PurifyExpedient() # original single selection
            success = purificationcircuit(regA[1], regB[1], regA[2:11], regB[2:11])
            @test success == true
        end
    end
end



