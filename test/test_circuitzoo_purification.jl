@testitem "Circuit Zoo Purification - throws" tags=[:circuitzoo_purification] begin
using QuantumSavory.CircuitZoo
using QuantumSavory.CircuitZoo: EntanglementSwap, Purify2to1, Purify3to1, Purify3to1Node, Purify2to1Node, PurifyStringent, StringentHead, StringentBody, PurifyExpedient, PurifyStringentNode, PurifyExpedient

const bell = StabilizerState("XX ZZ")
# or equivalently `const bell = (Z₁⊗Z₁+Z₂⊗Z₂)/√2`,
# however converting to stabilizer state for Clifford simulations
# is not implemented (and can not be done efficiently).


# QOptics repr
const perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
const perfect_pair_dm = SProjector(perfect_pair)
const mixed_dm = MixedState(perfect_pair_dm)
noisy_pair_func(F) = F*perfect_pair_dm + (1-F)*mixed_dm # TODO make a depolarization helper


# Qclifford repr
const stab_perfect_pair = StabilizerState("XX ZZ")
const stab_perfect_pair_dm = SProjector(stab_perfect_pair)
const stab_mixed_dm = MixedState(stab_perfect_pair_dm)
stab_noisy_pair_func(F) = F*stab_perfect_pair_dm + (1-F)*stab_mixed_dm

@test_throws ArgumentError Purify2to1(:lalala)
@test_throws ArgumentError Purify3to1(:lalala, :X)
@test_throws ArgumentError Purify2to1Node(:lalala)
@test_throws ArgumentError Purify3to1Node(:X, :lalala)
@test_throws ArgumentError StringentHead(:lalala)
@test_throws ArgumentError StringentBody(:lalala)

r = Register(30)
for i in 1:30
    initialize!(r[i], X1)
end
@test_throws ArgumentError PurifyExpedient()(r[1], r[2], r[3:2:21]...)
@test_throws ArgumentError PurifyStringent()(r[1], r[2], r[3:2:21]...)
end

@testitem "Circuit Zoo Purification - 2to1" tags=[:circuitzoo_purification] begin
    include("setup_circuitzoo_purification.jl")

    for rep in [QuantumOpticsRepr, CliffordRepr]
        for leaveout in [:X, :Y, :Z]
            # test that pure state gets mapped to pure state
            r = Register(4, rep())
            initialize!(r[1:4], bell⊗bell)
            @test Purify2to1(leaveout)(r[1:4]...)==true
            @test observable(r[1:2], projector(bell))≈1.0

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
end

@testitem "Circuit Zoo Purification - 2to1 - Node" tags=[:circuitzoo_purification] begin
    include("setup_circuitzoo_purification.jl")

    for rep in [QuantumOpticsRepr, CliffordRepr]
        for leaveout in [:X, :Y, :Z]
            # test that pure state gets mapped to pure state
            r = Register(4, rep())
            initialize!(r[1:4], bell⊗bell)
            ma = Purify2to1Node(leaveout)(r[1], r[3])
            mb = Purify2to1Node(leaveout)(r[2], r[4])
            @test ma == mb
            @test observable(r[1:2], projector(bell))≈1.0
            for error in [:X, :Y, :Z], target in 1:4
                r = Register(4, rep())
                initialize!(r[1:4], bell⊗bell)
                apply!(r[target], Dict(:X=>X, :Y=>Y, :Z=>Z)[error])
                if error==leaveout
                    # undetected error
                    ma = Purify2to1Node(leaveout)(r[1], r[3])
                    mb = Purify2to1Node(leaveout)(r[2], r[4])
                    @test ma == mb
                    @test observable(r[1:2], projector(bell))≈0.0
                else
                    # detected error
                    ma = Purify2to1Node(leaveout)(r[1], r[3])
                    mb = Purify2to1Node(leaveout)(r[2], r[4])
                    @test ma != mb
                end
            end
        end
    end
end

@testitem "Circuit Zoo Purification - 3to1" tags=[:circuitzoo_purification] begin
    include("setup_circuitzoo_purification.jl")

    for rep in [QuantumOpticsRepr, CliffordRepr]
        for leaveout1 in [:X, :Y, :Z]
            for leaveout2 in [:X, :Y, :Z]
                # test that pure state gets mapped to pure state
                if (leaveout1 != leaveout2)
                    r = Register(6, rep())
                    initialize!(r[1:6], bell⊗bell⊗bell)

                    @test Purify3to1(leaveout1, leaveout2)(r[1], r[2], r[3], r[5], r[4], r[6])==true
                    @test observable(r[1:2], projector(bell))≈1.0
                    for error in [:X, :Y, :Z], target in 3:6
                        r = Register(6, rep())
                        for i in 1:3
                            initialize!(r[(2*i-1):(2*i)], bell)
                        end
                        apply!(r[target], Dict(:X=>X, :Y=>Y, :Z=>Z)[error])
                        @test Purify3to1(leaveout1, leaveout2)(r[1], r[2], r[3], r[5], r[4], r[6])==false
                    end
                    for error in [:X, :Y, :Z], target in 1:2
                        r = Register(6, rep())
                        for i in 1:3
                            initialize!(r[(2*i-1):(2*i)], bell)
                        end
                        apply!(r[target], Dict(:X=>X, :Y=>Y, :Z=>Z)[error])

                        if error == leaveout1
                            @test Purify3to1(leaveout1, leaveout2)(r[1], r[2], r[3], r[5], r[4], r[6])==true
                            @test observable(r[1:2], projector(bell))≈0.0
                        else
                            @test Purify3to1(leaveout1, leaveout2)(r[1], r[2], r[3], r[5], r[4], r[6])==false
                        end
                    end
                end
            end
        end
    end
end

@testitem "Circuit Zoo Purification - 3to1 -- Fidelity - QuantumOpticsRepr" tags=[:circuitzoo_purification] begin
    include("setup_circuitzoo_purification.jl")

    for rep in [QuantumOpticsRepr]
        for leaveout1 in [:X, :Y, :Z]
            for leaveout2 in [:X, :Y, :Z]
                if (leaveout1 != leaveout2)
                    r = Register(6, rep())
                    rnd = rand() / 4 + 0.5
                    noisy_pair = noisy_pair_func(rnd)
                    initialize!(r[1:2], noisy_pair)
                    initialize!(r[3:4], noisy_pair)
                    initialize!(r[5:6], noisy_pair)
                    if Purify3to1(leaveout1, leaveout2)(r[1], r[2], r[3], r[5], r[4], r[6])==true
                        @test real(observable(r[1:2], projector(bell))) > rnd
                    end
                end
            end
        end
    end
end

@testitem "Circuit Zoo Purification - 3to1 -- Fidelity - CliffordRepr" tags=[:circuitzoo_purification] begin
    include("setup_circuitzoo_purification.jl")

    for rep in [CliffordRepr]
        for leaveout1 in [:X, :Y, :Z]
            for leaveout2 in [:X, :Y, :Z]
                if (leaveout1 != leaveout2)
                    r = Register(6, rep())
                    noisy_pair = stab_noisy_pair_func(0)
                    initialize!(r[1:2], noisy_pair)
                    initialize!(r[3:4], noisy_pair)
                    initialize!(r[5:6], noisy_pair)
                    if Purify3to1(leaveout1, leaveout2)(r[1], r[2], r[3], r[5], r[4], r[6])==true
                        @test_broken observable(r[1:2], projector(bell)) ≈ 0.0 # This is a probabilistic test. It has a small chance of triggering
                    end
                end
            end
        end
    end
end


@testitem "Circuit Zoo Purification - 3to1 -- Node" tags=[:circuitzoo_purification] begin
    include("setup_circuitzoo_purification.jl")

    for rep in [QuantumOpticsRepr, CliffordRepr]
        for leaveout1 in [:X, :Y, :Z]
            for leaveout2 in [:X, :Y, :Z]
                if (leaveout1 != leaveout2)
            # test that pure state gets mapped to pure state
                    r = Register(6, rep())
                    initialize!(r[1:6], bell⊗bell⊗bell)
                    ma = Purify3to1Node(leaveout1, leaveout2)(r[1], r[3],r[5])
                    mb = Purify3to1Node(leaveout1, leaveout2)(r[2], r[4],r[6])
                    @test ma == mb
                    @test observable(r[1:2], projector(bell)) ≈ 1.0

                    # TODO: Should also target qubits 1 and 2
                    for error in [:X, :Y, :Z], target in 3:6
                        r = Register(6, rep())
                        for i in 1:3
                            initialize!(r[(2*i-1):(2*i)], bell)
                        end
                        apply!(r[target], Dict(:X=>X, :Y=>Y, :Z=>Z)[error])
                        ma = Purify3to1Node(leaveout1, leaveout2)(r[1], r[3], r[5])
                        mb = Purify3to1Node(leaveout1, leaveout2)(r[2], r[4], r[6])
                        @test ma != mb
                    end

                    for error in [:X, :Y, :Z], target in 1:2
                        r = Register(6, rep())
                        for i in 1:3
                            initialize!(r[(2*i-1):(2*i)], bell)
                        end
                        apply!(r[target], Dict(:X=>X, :Y=>Y, :Z=>Z)[error])

                        if error == leaveout1
                            ma = Purify3to1Node(leaveout1, leaveout2)(r[1], r[3], r[5])
                            mb = Purify3to1Node(leaveout1, leaveout2)(r[2], r[4], r[6])
                            @test ma == mb
                            @test observable(r[1:2], projector(bell))≈0.0
                        else
                            ma = Purify3to1Node(leaveout1, leaveout2)(r[1], r[3], r[5])
                            mb = Purify3to1Node(leaveout1, leaveout2)(r[2], r[4], r[6])
                            @test ma != mb
                        end
                    end
                end
            end
        end
    end
end

@testitem "Circuit Zoo Purification - 3to1 -- Node - Fidelity - QuantumOpticsRepr" tags=[:circuitzoo_purification] begin
    include("setup_circuitzoo_purification.jl")

    for rep in [QuantumOpticsRepr]
        for leaveout1 in [:X, :Y, :Z]
            for leaveout2 in [:X, :Y, :Z]
                if (leaveout1 != leaveout2)
                    r = Register(6, rep())
                    rnd = rand() / 4 + 0.5
                    noisy_pair = noisy_pair_func(rnd)
                    initialize!(r[1:2], noisy_pair)
                    initialize!(r[3:4], noisy_pair)
                    initialize!(r[5:6], noisy_pair)
                    ma = Purify3to1Node(leaveout1, leaveout2)(r[1], r[3], r[5])
                    mb = Purify3to1Node(leaveout1, leaveout2)(r[2], r[4], r[6])
                    if ma == mb
                        @test real(observable(r[1:2], projector(bell))) > rnd
                    end
                end
            end
        end
    end
end

@testitem "Circuit Zoo Purification - 3to1 -- Node - Fidelity - CliffordRepr" tags=[:circuitzoo_purification] begin
    include("setup_circuitzoo_purification.jl")

    for rep in [CliffordRepr]
        for leaveout1 in [:X, :Y, :Z]
            for leaveout2 in [:X, :Y, :Z]
                if (leaveout1 != leaveout2)
                    r = Register(6, rep())
                    noisy_pair = stab_noisy_pair_func(0)
                    initialize!(r[1:2], noisy_pair)
                    initialize!(r[3:4], noisy_pair)
                    initialize!(r[5:6], noisy_pair)
                    ma = Purify3to1Node(leaveout1, leaveout2)(r[1], r[3], r[5])
                    mb = Purify3to1Node(leaveout1, leaveout2)(r[2], r[4], r[6])
                    if ma == mb
                        @test_broken observable(r[1:2], projector(bell)) ≈ 0.0 # This is a probabilistic test. It has a small chance of triggering
                    end
                end
            end
        end
    end
end

@testitem "Circuit Zoo Purification - Stringent" tags=[:circuitzoo_purification] begin
    include("setup_circuitzoo_purification.jl")

    for rep in [CliffordRepr, QuantumOpticsRepr]
        r = Register(26, rep())
        for i in 1:13
            initialize!(r[(2*i-1):(2*i)], bell)
        end
        @test PurifyStringent()(r[1], r[2], r[3:2:25]..., r[4:2:26]...) == true
        @test observable(r[1:2], projector(bell)) ≈ 1.0
    end
    end

    @testitem "Circuit Zoo Purification - Stringent - Fidelity - QuantumOpticsRepr" tags=[:circuitzoo_purification] begin
    include("setup_circuitzoo_purification.jl")

    for rep in [QuantumOpticsRepr]
        r = Register(26, rep())
        rnd = rand() / 4 + 0.5
        noisy_pair = noisy_pair_func(rnd)
        for i in 1:13
            initialize!(r[(2*i-1):(2*i)], noisy_pair)
        end
        if PurifyStringent()(r[1], r[2], r[3:2:25]..., r[4:2:26]...) == true
            @test real(observable(r[1:2], projector(bell))) > rnd
        end
    end
end

@testitem "Circuit Zoo Purification - Stringent - Fidelity - CliffordRepr" tags=[:circuitzoo_purification] begin
    include("setup_circuitzoo_purification.jl")

    for rep in [CliffordRepr]
        r = Register(26, rep())
        noisy_pair = stab_noisy_pair_func(0)
        for i in 1:13
            initialize!(r[(2*i-1):(2*i)], noisy_pair)
        end
        if PurifyStringent()(r[1], r[2], r[3:2:25]..., r[4:2:26]...) == true
            @test_broken observable(r[1:2], projector(bell)) ≈ 0.0 # This is a probabilistic test. It has a small chance of triggering
        end
    end
end

@testitem "Circuit Zoo Purification - Expedient" tags=[:circuitzoo_purification] begin
    include("setup_circuitzoo_purification.jl")

    for rep in [CliffordRepr, QuantumOpticsRepr]
        r = Register(22, rep())
        for i in 1:11
            initialize!(r[(2*i-1):(2*i)], bell)
        end
        @test PurifyExpedient()(r[1], r[2], r[3:2:21]..., r[4:2:22]...) == true
        @test observable(r[1:2], projector(bell)) ≈ 1.0
    end
end

@testitem "Circuit Zoo Purification - Expedient - Fidelity - QuantumOpticsRepr" tags=[:circuitzoo_purification] begin
    include("setup_circuitzoo_purification.jl")

    for rep in [QuantumOpticsRepr]
        r = Register(22, rep())
        rnd = rand() / 4 + 0.5
        noisy_pair = noisy_pair_func(rnd)
        for i in 1:11
            initialize!(r[(2*i-1):(2*i)], noisy_pair)
        end
        if PurifyExpedient()(r[1], r[2], r[3:2:21]..., r[4:2:22]...) == true
            @test real(observable(r[1:2], projector(bell))) > rnd
        end
    end
end

@testitem "Circuit Zoo Purification - Expedient - Fidelity - CliffordRepr" tags=[:circuitzoo_purification] begin
    include("setup_circuitzoo_purification.jl")

    for rep in [CliffordRepr]
        r = Register(22, rep())
        noisy_pair = stab_noisy_pair_func(0)
        for i in 1:11
            initialize!(r[(2*i-1):(2*i)], noisy_pair)
        end
        if PurifyExpedient()(r[1], r[2], r[3:2:21]..., r[4:2:22]...) == true
            @test_broken observable(r[1:2], projector(bell)) ≈ 0.0 # This is a probabilistic test. It has a small chance of triggering
        end
    end
end
