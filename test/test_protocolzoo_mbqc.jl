@testitem "ProtocolZoo MBQC" tags=[:protocolzoo_mbqc] begin

using QuantumSavory
using QuantumSavory.ProtocolZoo
using ConcurrentSim
using ResumableFunctions
using Graphs
using Random
import QuantumClifford
import QuantumOpticsBase
using QuantumClifford: stab_to_gf2, graphstate, Stabilizer, MixedDestabilizer, single_x, single_z, logicalxview, logicalzview
using QuantumClifford.ECC: CSS, parity_checks

@testset "GraphStateConstructor" begin
    communication_slot = 1
    storage_slot = 2

    for _ in 1:5
        n = rand(3:8)
        g = erdos_renyi(n, 0.4)
        while !is_connected(g) || ne(g) == 0
            g = erdos_renyi(n, 0.4)
        end

        registers = [Register(2) for _ in 1:n]
        net = RegisterNet(registers)
        sim = get_time_tracker(net)

        nodes = collect(1:n)
        graphconstructor = GraphStateConstructor(sim, net, g, nodes, communication_slot, storage_slot)
        @process graphconstructor()
        run(sim, 50.0)

        for i in 1:nv(g)
            o = observable([reg[storage_slot] for reg in registers], QuantumOpticsBase.Operator(QuantumClifford.Stabilizer(g)[i]))
            @test o ≈ 1.0
        end
    end
end

@testset "Full Purification Pipeline" begin
    # Set up [4,2] CSS code (same as paper_implementation.jl)
    h1 = [1 1 1 1]
    h2 = [1 1 1 1]
    code = parity_checks(CSS(h1, h2)) # == S"XXXX ZZZZ"
    c, n = size(code)
    k = n - c
    code_binary = stab_to_gf2(code)
    H1 = code_binary[:, 1:n]
    H2 = code_binary[:, n+1:end]
    code_md = MixedDestabilizer(code)
    logxs = logicalxview(code_md)
    logzs = logicalzview(code_md)

    # Build the resource state (equation 1 from the paper)
    resource_state = vcat(
        hcat(code, zero(Stabilizer, c, k)),
        Stabilizer([l⊗single_x(k,i) for (i,l) in enumerate(logxs)]),
        Stabilizer([l⊗single_z(k,i) for (i,l) in enumerate(logzs)]),
    )

    communication_slot = 1
    storage_slot = 2
    alice_nodes = 1:n+k
    bob_nodes = n+k+1:2*(n+k)
    alice_chief_idx = alice_nodes[1]
    bob_chief_idx = bob_nodes[1]

    perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)

    registers = [Register(2) for _ in 1:2*(n+k)]
    net = RegisterNet(registers)
    sim = get_time_tracker(net)

    g, hadamard_idx, iphase_idx, flips_idx = graphstate(resource_state)

    # Step 1: Construct graph states on both sides
    graphA = GraphStateConstructor(sim, net, g, collect(alice_nodes), communication_slot, storage_slot)
    graphB = GraphStateConstructor(sim, net, g, collect(bob_nodes), communication_slot, storage_slot)

    @resumable function build_graph_states(sim)
        g1 = @process graphA()
        g2 = @process graphB()
        @yield g1 & g2
    end
    @process build_graph_states(sim)
    run(sim, 5.0)

    # Verify graph states
    alice_regs = [net[i][storage_slot] for i in alice_nodes]
    bob_regs = [net[i][storage_slot] for i in bob_nodes]
    for i in 1:nv(g)
        @test observable(alice_regs, QuantumOpticsBase.Operator(QuantumClifford.Stabilizer(g)[i])) ≈ 1.0
        @test observable(bob_regs, QuantumOpticsBase.Operator(QuantumClifford.Stabilizer(g)[i])) ≈ 1.0
    end

    # Step 2: Convert graph states to resource states and establish entanglement
    resourceA = GraphToResource(sim, net, collect(alice_nodes), storage_slot, hadamard_idx, iphase_idx, flips_idx)
    resourceB = GraphToResource(sim, net, collect(bob_nodes), storage_slot, hadamard_idx, iphase_idx, flips_idx)

    @resumable function prepare_resources(sim)
        r1 = @process resourceA()
        r2 = @process resourceB()
        entanglers = []
        for i in 1:n
            entangler = EntanglerProt(sim, net, alice_nodes[i], bob_nodes[i];
                pairstate=perfect_pair,
                chooseA=communication_slot, chooseB=communication_slot,
                success_prob=1.0, attempts=-1, rounds=1)
            e = @process entangler()
            push!(entanglers, e)
        end
        @yield reduce(&, (entanglers..., r1, r2))
    end
    @process prepare_resources(sim)
    run(sim, 10.0)

    # Verify resource states
    for i in 1:length(resource_state)
        @test observable(alice_regs, QuantumOpticsBase.Operator(resource_state[i])) ≈ 1.0
        @test observable(bob_regs, QuantumOpticsBase.Operator(resource_state[i])) ≈ 1.0
    end

    # Verify entangled pairs
    for i in 1:n
        @test observable([net[alice_nodes[i]], net[bob_nodes[i]]], [communication_slot, communication_slot], projector(perfect_pair)) ≈ 1.0
    end

    # Step 3: Bell measurements and purification tracking
    alice_bell_meas = PurifierBellMeasurements(sim, net, collect(alice_nodes[1:n]), alice_chief_idx, bob_chief_idx, communication_slot, storage_slot)
    bob_bell_meas = PurifierBellMeasurements(sim, net, collect(bob_nodes[1:n]), bob_chief_idx, alice_chief_idx, communication_slot, storage_slot)

    alice_tracker = MBQCPurificationTracker(sim, net, collect(alice_nodes), n, alice_chief_idx, bob_chief_idx, H1, H2, logxs, logzs, communication_slot, storage_slot, false)
    bob_tracker = MBQCPurificationTracker(sim, net, collect(bob_nodes), n, bob_chief_idx, alice_chief_idx, H1, H2, logxs, logzs, communication_slot, storage_slot, true)

    @process alice_tracker()
    @process bob_tracker()

    @resumable function run_measurements(sim)
        m1 = @process alice_bell_meas()
        m2 = @process bob_bell_meas()
        @yield m1 & m2
    end
    @process run_measurements(sim)
    run(sim, 20.0)

    # Verify purification succeeded
    for i in 1:k
        alice_tag = query(net[alice_chief_idx + n + i - 1][storage_slot], PurifiedEntanglementCounterpart, ❓, ❓)
        bob_tag = query(net[bob_chief_idx + n + i - 1][storage_slot], PurifiedEntanglementCounterpart, ❓, ❓)
        @test !isnothing(alice_tag) || !isnothing(bob_tag)
    end
end

end
