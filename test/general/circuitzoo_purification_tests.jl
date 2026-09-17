using Test
using QuantumSavory
using QuantumSavory.CircuitZoo
using QuantumSavory.CircuitZoo: EntanglementSwap, Purify2to1, Purify3to1, Purify3to1Node, Purify2to1Node, PurifyStringent, StringentHead, StringentBody, PurifyExpedient, PurifyStringentNode, PurifyExpedient
include("setup_circuitzoo_purification.jl")

# A maximally mixed Bell pair is the uniform mixture of these four trajectories.
# Enumerating them keeps the Clifford fidelity tests deterministic and guarantees
# that every acceptance and fidelity assertion is exercised.
const clifford_target_errors = ((:I, nothing), (:X, X), (:Y, Y), (:Z, Z))

function clifford_pairs_with_target_error(pair_count, error)
    r = Register(2 * pair_count, CliffordRepr())
    for i in 1:pair_count
        initialize!(r[(2 * i - 1):(2 * i)], bell)
    end
    !isnothing(error) && apply!(r[1], error)
    r
end

function clifford_bell_fidelity(r)
    (1 + observable(r[1:2], X ⊗ X) - observable(r[1:2], Y ⊗ Y) +
     observable(r[1:2], Z ⊗ Z)) / 4
end

@testset "Circuit Zoo Purification - throws" begin

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

@testset "Circuit Zoo Purification - 2to1" begin

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
                    @test observable(r[1:2], projector(bell)) ≈ 0.0 atol=1e-5
                else
                    # detected error
                    @test Purify2to1(leaveout)(r[1:4]...)==false
                end
            end
        end
    end
end

@testset "Circuit Zoo Purification - 2to1 - Node" begin

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
                    @test observable(r[1:2], projector(bell)) ≈ 0.0 atol=1e-5
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

@testset "Circuit Zoo Purification - 3to1" begin

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
                            @test observable(r[1:2], projector(bell)) ≈ 0.0 atol=1e-5
                        else
                            @test Purify3to1(leaveout1, leaveout2)(r[1], r[2], r[3], r[5], r[4], r[6])==false
                        end
                    end
                end
            end
        end
    end
end

@testset "Circuit Zoo Purification - 3to1 -- Fidelity - QuantumOpticsRepr" begin

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

@testset "Circuit Zoo Purification - 3to1 -- Fidelity - CliffordRepr" begin

    for leaveout1 in [:X, :Y, :Z]
        for leaveout2 in [:X, :Y, :Z]
            if leaveout1 != leaveout2
                accepted = Pair{Symbol, Float64}[]
                for (error_name, error) in clifford_target_errors
                    r = clifford_pairs_with_target_error(3, error)
                    success = Purify3to1(leaveout1, leaveout2)(
                        r[1], r[2], r[3], r[5], r[4], r[6])
                    success && push!(accepted, error_name => clifford_bell_fidelity(r))
                end
                @test first.(accepted) == [:I, leaveout1]
                @test last.(accepted) ≈ [1.0, 0.0]
                @test sum(last, accepted) / length(accepted) ≈ 0.5
            end
        end
    end
end


@testset "Circuit Zoo Purification - 3to1 -- Node" begin

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
                            @test observable(r[1:2], projector(bell)) ≈ 0.0 atol=1e-5
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

@testset "Circuit Zoo Purification - 3to1 -- Node - Fidelity - QuantumOpticsRepr" begin

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

@testset "Circuit Zoo Purification - 3to1 -- Node - Fidelity - CliffordRepr" begin

    for leaveout1 in [:X, :Y, :Z]
        for leaveout2 in [:X, :Y, :Z]
            if leaveout1 != leaveout2
                accepted = Pair{Symbol, Float64}[]
                for (error_name, error) in clifford_target_errors
                    r = clifford_pairs_with_target_error(3, error)
                    ma = Purify3to1Node(leaveout1, leaveout2)(r[1], r[3], r[5])
                    mb = Purify3to1Node(leaveout1, leaveout2)(r[2], r[4], r[6])
                    ma == mb && push!(accepted,
                        error_name => clifford_bell_fidelity(r))
                end
                @test first.(accepted) == [:I, leaveout1]
                @test last.(accepted) ≈ [1.0, 0.0]
                @test sum(last, accepted) / length(accepted) ≈ 0.5
            end
        end
    end
end

@testset "Circuit Zoo Purification - Stringent" begin

    for rep in [CliffordRepr, QuantumOpticsRepr]
        r = Register(26, rep())
        for i in 1:13
            initialize!(r[(2*i-1):(2*i)], bell)
        end
        @test PurifyStringent()(r[1], r[2], r[3:2:25]..., r[4:2:26]...) == true
        @test observable(r[1:2], projector(bell)) ≈ 1.0
    end
    end

    @testset "Circuit Zoo Purification - Stringent - Fidelity - QuantumOpticsRepr" begin

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

@testset "Circuit Zoo Purification - Stringent - Fidelity - CliffordRepr" begin

    accepted = Pair{Symbol, Float64}[]
    for (error_name, error) in clifford_target_errors
        r = clifford_pairs_with_target_error(13, error)
        if PurifyStringent()(r[1], r[2], r[3:2:25]..., r[4:2:26]...)
            push!(accepted, error_name => clifford_bell_fidelity(r))
        end
    end
    @test first.(accepted) == [:I]
    @test last.(accepted) ≈ [1.0]
end

@testset "Circuit Zoo Purification - Expedient" begin

    for rep in [CliffordRepr, QuantumOpticsRepr]
        r = Register(22, rep())
        for i in 1:11
            initialize!(r[(2*i-1):(2*i)], bell)
        end
        @test PurifyExpedient()(r[1], r[2], r[3:2:21]..., r[4:2:22]...) == true
        @test observable(r[1:2], projector(bell)) ≈ 1.0
    end
end

@testset "Circuit Zoo Purification - Expedient - Fidelity - QuantumOpticsRepr" begin

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

@testset "Circuit Zoo Purification - Expedient - Fidelity - CliffordRepr" begin

    accepted = Pair{Symbol, Float64}[]
    for (error_name, error) in clifford_target_errors
        r = clifford_pairs_with_target_error(11, error)
        if PurifyExpedient()(r[1], r[2], r[3:2:21]..., r[4:2:22]...)
            push!(accepted, error_name => clifford_bell_fidelity(r))
        end
    end
    @test first.(accepted) == [:I]
    @test last.(accepted) ≈ [1.0]
end
