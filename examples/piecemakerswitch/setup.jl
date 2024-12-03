using QuantumSavory
using QuantumSavory.ProtocolZoo
using Graphs
using ConcurrentSim
using ResumableFunctions
using Distributions
using DataFrames
using CSV
using Profile
using NetworkLayout

@resumable function init_state(sim, net, nclients, delay)
    @yield timeout(sim, delay)
    initialize!(net[1][nclients+1], X1; time=now(sim))
end

@resumable function entangle_and_fuse(sim, net, client, link_success_prob)

    # Set up the entanglement trackers at each client
    tracker = EntanglementTracker(sim, net, client) 
    @process tracker()

    # Set up the entangler and fuser protocols at each client
    entangler = EntanglerProt(
        sim=sim, net=net, nodeA=1, slotA=client-1, nodeB=client,
        success_prob=link_success_prob, rounds=1, attempts=-1, attempt_time=1.0 
        )
    @yield @process entangler()

    fuser = FusionProt(
            sim=sim, net=net, node=1,
            nodeC=client,
            rounds=1
        )
    @yield @process fuser()
end


@resumable function run_protocols(sim, net, nclients, link_success_prob)
    # Run entangler and fusion for each client and wait for all to finish
    procs_succeeded = []
    for k in 2:nclients+1    
        proc_succeeded = @process entangle_and_fuse(sim, net, k, link_success_prob)
        push!(procs_succeeded, proc_succeeded)
    end
    @yield reduce(&, procs_succeeded)
end

function prepare_simulation(nclients=2, mem_depolar_prob = 0.1, link_success_prob = 0.5)

    m = nclients+1 # memory slots in switch is equal to the number of clients + 1 slot for piecemaker qubit
    r_depol =  - log(1 - mem_depolar_prob) # depolarization rate
    delay = 1 # initialize the piecemaker |+> after one time unit (in order to provide fidelity ==1 if success probability = 1)

    # The graph of network connectivity. Index 1 corresponds to the switch.
    graph = star_graph(nclients+1)

    switch_register = Register(m, Depolarization(1/r_depol)) # the first slot is reserved for the 'piecemaker' qubit used as fusion qubit 
    client_registers = [Register(1, Depolarization(1/r_depol)) for _ in 1:nclients] #Depolarization(1/r_depol)
    net = RegisterNet(graph, [switch_register, client_registers...])
    sim = get_time_tracker(net)

    @process init_state(sim, net, nclients, delay)
    
    # Run entangler and fusion for each client and wait for all to finish
    @process run_protocols(sim, net, nclients, link_success_prob)

    # Set up the consumer to measure final entangled state
    consumer = FusionConsumer(net, net[1][m]; period=0.001)
    @process consumer()

    return sim, consumer
end


