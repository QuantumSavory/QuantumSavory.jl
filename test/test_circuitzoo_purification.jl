using QuantumSavory
using QuantumSavory.CircuitZoo
using Test

const bell = StabilizerState("XX ZZ")
# or equivalently `const bell = (Z₁⊗Z₁+Z₂⊗Z₂)/√2`,
# however converting to stabilizer state for Clifford simulations
# is not implemented (and can not be done efficiently).

@test_throws ArgumentError Purify2to1(:lalala)

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
