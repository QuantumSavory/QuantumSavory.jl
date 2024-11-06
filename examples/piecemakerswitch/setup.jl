using QuantumSavory
using QuantumSavory.ProtocolZoo
using Graphs
using ConcurrentSim
using ResumableFunctions
using Distributions
using DataFrames
using CSV
using StatsPlots
        

function prepare_simulation(nclients=2, mem_depolar_prob = 0.1, link_success_prob = 0.5)

    m = nclients+1 # memory slots in switch is equal to the number of clients + 1 slot for piecemaker qubit
    r_depol =  - log(1 - mem_depolar_prob) # depolarization rate

    # The graph of network connectivity. Index 1 corresponds to the switch.
    graph = star_graph(nclients+1)

    switch_register = Register(m, Depolarization(1/r_depol)) # the first slot is reserved for the 'piecemaker' qubit used as fusion qubit 
    client_registers = [Register(1, Depolarization(1/r_depol)) for _ in 1:nclients] #Depolarization(1/r_depol)
    net = RegisterNet(graph, [switch_register, client_registers...])
    sim = get_time_tracker(net)

    # Set up the initial |+> state of the piecemaker qubit
    initialize!(net[1][m], X1)
    tag!(net[1][m], Piecemaker, 1, m)

    event_ghz_state = Event(sim)

    # Set up the entanglement trackers at each client
    trackers = [EntanglementTracker(sim, net, k) for k in 2:nclients+1]
    for tracker in trackers
        @process tracker()
    end

    # Set up an entanglement consumer between each unordered pair of clients
    consumer = GHZConsumer(net, net[1][m], event_ghz_state; period=1)
    @process consumer()

    # Finally, set up the switch without assignments
    switch_protocol = FusionSwitchDiscreteProt(net, 1, 2:nclients+1, fill(link_success_prob, nclients); ticktock=1)
    @process switch_protocol()
    
    return sim, consumer
end
