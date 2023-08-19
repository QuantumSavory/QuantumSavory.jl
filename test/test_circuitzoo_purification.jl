using QuantumSavory
using QuantumSavory.CircuitZoo
using Test
using QuantumSavory.CircuitZoo: EntanglementSwap, Purify2to1, Purify3to1, PurifyStringent, PurifyExpedient


const bell = StabilizerState("XX ZZ")
const bgd = T2Dephasing(1.0)
# or equivalently `const bell = (Z₁⊗Z₁+Z₂⊗Z₂)/√2`,
# however converting to stabilizer state for Clifford simulations
# is not implemented (and can not be done efficiently).

const perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
const perfect_pair_dm = SProjector(perfect_pair)
const mixed_dm = MixedState(perfect_pair_dm)
noisy_pair_func(F) = F*perfect_pair_dm + (1-F)*mixed_dm # TODO make a depolarization helper


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
            # TODO: Should also taget qubits 1 and 2
            for error in [:X, :Y, :Z], target in 1:4
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

    for rep in [QuantumOpticsRepr]
        for leaveout in [:X, :Y, :Z]
            r = Register(4, rep())
            rnd = rand() / 4 + 0.5
            noisy_pair = noisy_pair_func(rnd)
            initialize!(r[1:2], noisy_pair)
            initialize!(r[3:4], noisy_pair)
            if Purify2to1(leaveout)(r[1:4]...)==true
                @test abs(observable(r[1:2], projector(bell))) >= rnd
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
            # TODO: Should also taget qubits 1 and 2
            for error in [:X, :Y, :Z], target in 3:6
                r = Register(6, rep())
                for i in 1:3
                    initialize!(r[(2*i-1):(2*i)], bell)
                end
                apply!(r[target], Dict(:X=>X, :Y=>Y, :Z=>Z)[error])
                @test Purify3to1(fixtwice)(r[1], r[2], [r[3], r[5]], [r[4], r[6]])==false
            end
            # When [error, fixtwice] in {[X,Z], [Z,Y], [Y,X]} it yields true is that supposed to happen?
            for error in [:X, :Y, :Z], target in 1:2
                r = Register(6, rep())
                for i in 1:3
                    initialize!(r[(2*i-1):(2*i)], bell)
                end
                apply!(r[target], Dict(:X=>X, :Y=>Y, :Z=>Z)[error])

                if Dict(:X=>:Z, :Y=>:X, :Z=>:Y)[error] == fixtwice
                    @test Purify3to1(fixtwice)(r[1], r[2], [r[3], r[5]], [r[4], r[6]])==true
                    @test observable(r[1:2], projector(bell))≈0.0
                else
                    @test Purify3to1(fixtwice)(r[1], r[2], [r[3], r[5]], [r[4], r[6]])==false
                end
            end
        end
    end
    # testing fidelity - Error when using CliffordRepr
    for rep in [QuantumOpticsRepr]
        for fixtwice in [:X, :Y, :Z]
            r = Register(6, rep())
            rnd = rand() / 4 + 0.5
            noisy_pair = noisy_pair_func(rnd)
            initialize!(r[1:2], noisy_pair)
            initialize!(r[3:4], noisy_pair)
            initialize!(r[5:6], noisy_pair)
            if Purify3to1(fixtwice)(r[1], r[2], [r[3], r[5]], [r[4], r[6]])==true
                @test abs(observable(r[1:2], projector(bell))) >= rnd
            end
        end
    end
end

@testset "Stringent" begin
    for rep in [CliffordRepr, QuantumOpticsRepr]
        r = Register(26, rep())
        for i in 1:13
            initialize!(r[(2*i-1):(2*i)], bell)
        end

        # 3:2:25 ...
        @test PurifyStringent()(r[1], r[2], r[3:2:25], r[4:2:26]) == true 
    end
    # testing fidelity - Error when using CliffordRepr
    for rep in [QuantumOpticsRepr]
        r = Register(26, rep())
        rnd = rand() / 4 + 0.5
        noisy_pair = noisy_pair_func(rnd)
        for i in 1:13
            initialize!(r[(2*i-1):(2*i)], noisy_pair)
        end
        if PurifyStringent()(r[1], r[2], r[3:2:25], r[4:2:26]) == true
            @test abs(observable(r[1:2], projector(bell))) >= rnd
        end
    end
end
