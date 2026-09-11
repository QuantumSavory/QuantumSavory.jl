using Test
using QuantumSavory
using ConcurrentSim

# Include the setup
include("../../examples/butterflynetwork/setup.jl")

@testset "Butterfly Network Setup" begin
    sim, network = simulation_setup(; regsize=4, T2=100.0)
    
    @test sim isa Environment
    @test network isa RegisterNet
    @test nv(network.graph) == 6
    @test ne(network.graph) == 7
    
    # Check that registers were created
    @test length(network.registers) == 6
    for reg in network.registers
        @test nsubsystems(reg) == 4
    end
    
    # Check enttrackers initialization
    for v in vertices(network)
        @test length(network[v, :enttrackers]) == 4
        @test all(isnothing.(network[v, :enttrackers]))
    end
end

@testset "Butterfly Network Entanglement Generation" begin
    sim, network = simulation_setup(; regsize=2, T2=100.0)
    noisy_pair = noisy_pair_func(0.95)
    
    # Run entangler on one edge for a short time
    @process entangler(sim, network, 1, 3, noisy_pair, 0.01, 0.1)
    run(sim, 0.5)
    
    # Check if at least one entanglement was established
    enttrackers_1 = network[1, :enttrackers]
    enttrackers_3 = network[3, :enttrackers]
    
    has_entanglement = any(!isnothing.(enttrackers_1)) || any(!isnothing.(enttrackers_3))
    @test has_entanglement
end
