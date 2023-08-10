using QuantumSavory
using QuantumSavory.CircuitZoo
using Test
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

# @testset "Keep Pure I Entanglement with :Y" begin
#     @testset "Purify2to1" begin
#         for _ in 1:10
#             regA, regB = entangled_registers(2, 1)
#             purificationcircuit = Purify2to1(:Y) # original single selection
#             success = purificationcircuit(regA[1], regB[1], regA[2], regB[2])
#             @test success == true
#         end
#     end

#     @testset "Purify3to1" begin
#         for _ in 1:10
#             regA, regB = entangled_registers(3, 1)
#             purificationcircuit = Purify3to1(:Y) # original double selection
#             success = purificationcircuit(regA[1], regB[1], [regA[2], regA[3]], [regB[2], regB[3]])
#             @test success == true
#         end
#     end

#     @testset "PurifyStringent" begin
#         for _ in 1:10
#             regA, regB = entangled_registers(13, 1)
#             purificationcircuit = PurifyStringent() # original single selection
#             success = purificationcircuit(regA[1], regB[1], regA[2:13], regB[2:13])
#             @test success == true
#         end
#     end

#     @testset "PurifyExpedient" begin
#         for _ in 1:10
#             regA, regB = entangled_registers(11, 1)
#             purificationcircuit = PurifyExpedient() # original single selection
#             success = purificationcircuit(regA[1], regB[1], regA[2:11], regB[2:11])
#             @test success == true
#         end
#     end
# end



const bell = StabilizerState("XX ZZ")
# or equivalently `const bell = (Z₁⊗Z₁+Z₂⊗Z₂)/√2`,
# however converting to stabilizer state for Clifford simulations
# is not implemented (and can not be done efficiently).

# @test_throws ArgumentError Purify2to1(:lalala)

@testset "2to1" begin
    for rep in [QuantumOpticsRepr, CliffordRepr]
        for leaveout in [:X, :Y, :Z]
            # test that pure state gets mapped to pure state
            r = Register(4, rep())
            initialize!(r[1:4], bell⊗bell)
            @test Purify2to1(leaveout)(r[1:4]...)==true
            @test observable(r[1:2], projector(bell))≈1.0

            # test that single qubit errors are detected as expected
            for error in [:X, :Y, :Z], target in 3:4
                r = Register(4, rep())
                initialize!(r[1:4], bell⊗bell)
                apply!(r[target], Dict(:X=>X, :Y=>Y, :Z=>Z)[error])
                if error==leaveout
                    # undetected error
                    @test Purify2to1(leaveout)(r[1:4]...)==true
                    @test observable(r[1:2], projector(bell))≈0.0
                else
                    # detected error
                    @test Purify2to1(leaveout)(r[1:4]...)==false
                end
            end
        end
    end
end

@testset "3to1" begin
    for rep in [QuantumOpticsRepr, CliffordRepr]
        for fixtwice in [:X, :Y, :Z]
            # test that pure state gets mapped to pure state
            r = Register(6, rep())
            initialize!(r[1:6], bell⊗bell⊗bell)
            @test Purify3to1(fixtwice)(r[1], r[2], [r[3], r[5]], [r[4], r[6]])==true
            @test observable(r[1:2], projector(bell))≈1.0

            for error in [:X, :Y, :Z], target in 3:6
                r = Register(6, rep())
                initialize!(r[1:6], bell⊗bell⊗bell)
                apply!(r[target], Dict(:X=>X, :Y=>Y, :Z=>Z)[error])
                @test Purify3to1(fixtwice)(r[1], r[2], [r[3], r[5]], [r[4], r[6]])==false
            end
            
        end
    end
end
