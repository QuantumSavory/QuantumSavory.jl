using Test

@testset "Examples - firstgenrepeater_lowlevel 6.1" begin
    include("../../examples/firstgenrepeater_lowlevel/6.1_compare_formalisms_noplot.jl")

    fidelity = 0.83
    pair = Register(2, QuantumOpticsRepr())
    initialize!(pair[1:2], stab_noisy_pair_func(fidelity))
    @test real(observable(pair[1:2], perfect_pair_dm)) ≈ fidelity
end
