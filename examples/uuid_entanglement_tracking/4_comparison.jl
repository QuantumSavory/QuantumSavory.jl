"""
Example comparing UUID-based and history-based protocols.

This demonstrates the performance characteristics of both approaches
on the same network topology.
"""

using QuantumSavory
using QuantumSavory.ProtocolZoo
using ConcurrentSim

function run_uuid_protocol(num_nodes::Int)
    net = RegisterNet([Register(5) for _ in 1:num_nodes])
    sim = get_time_tracker(net)
    
    # Create all entanglers
    for i in 1:(num_nodes-1)
        entangler = EntanglerProtUUID(sim, net, i, i+1; rounds=1)
        @process entangler()
    end
    run(sim, 100)
    
    # Create swappers and trackers
    for i in 2:(num_nodes-1)
        swapper = SwapperProtUUID(sim, net, i; nodeL=<(i), nodeH=>(i), rounds=-1)
        tracker = EntanglementTrackerUUID(sim, net, i)
        @process swapper()
        @process tracker()
    end
    
    run(sim, 1000)
    return sim
end

function run_history_protocol(num_nodes::Int)
    net = RegisterNet([Register(5) for _ in 1:num_nodes])
    sim = get_time_tracker(net)
    
    # Create all entanglers
    for i in 1:(num_nodes-1)
        entangler = EntanglerProt(sim, net, i, i+1; rounds=1)
        @process entangler()
    end
    run(sim, 100)
    
    # Create swappers and trackers
    for i in 2:(num_nodes-1)
        swapper = SwapperProt(sim, net, i; nodeL=<(i), nodeH=>(i), rounds=-1)
        tracker = EntanglementTracker(sim, net, i)
        @process swapper()
        @process tracker()
    end
    
    run(sim, 1000)
    return sim
end

# Compare both protocols
for num_nodes in [3, 5, 7]
    println("\nNetwork size: $num_nodes nodes")
    
    # Run UUID-based
    t_uuid_start = time()
    sim_uuid = run_uuid_protocol(num_nodes)
    t_uuid = time() - t_uuid_start
    
    # Run history-based
    t_history_start = time()
    sim_history = run_history_protocol(num_nodes)
    t_history = time() - t_history_start
    
    println("  UUID protocol - Simulation time: $(now(sim_uuid)), Wall time: $(round(t_uuid, digits=4))s")
    println("  History protocol - Simulation time: $(now(sim_history)), Wall time: $(round(t_history, digits=4))s")
    println("  Speedup: $(round(t_history/t_uuid, digits=2))x")
end
