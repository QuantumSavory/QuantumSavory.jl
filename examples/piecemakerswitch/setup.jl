using QuantumSavory
using QuantumSavory.ProtocolZoo
using Graphs
using ConcurrentSim
using ResumableFunctions
using Distributions
using DataFrames

# @resumable function init_piecemaker(sim, net, m)
#     while true
#         @yield lock(net[1][m])
#         if !isassigned(net[1][m])
#             initialize!(net[1][m], X1)
#             tag!(net[1][m], Piecemaker, 1, m)
#             unlock(net[1][m])
#             @yield timeout(sim, 1e-9)
#         else
#             unlock(net[1][m])
#             @yield timeout(sim, 1e-9)
#         end
#     end
# end
        

function prepare_simulation()
    n = 10   # number of clients
    m = n+1 # memory slots in switch is equal to the number of clients + 1 slot for piecemaker qubit
    depolar_prob = 0.1
    r_depol =  - log(1 - depolar_prob) # depolarization rate

    # The graph of network connectivity. Index 1 corresponds to the switch.
    graph = star_graph(n+1)

    switch_register = Register(m, Depolarization(1/r_depol)) # the first slot is reserved for the 'piecemaker' qubit used as fusion qubit 
    client_registers = [Register(1,  Depolarization(1/r_depol)) for _ in 1:n]
    @info switch_register.reprs[1]
    net = RegisterNet(graph, [switch_register, client_registers...])
    sim = get_time_tracker(net)

    # Set up the initial |+> state of the piecemaker qubit
    initialize!(net[1][m], X1)
    tag!(net[1][m], Piecemaker, 1, m)

    event_ghz_state = Event(sim)

    # Set up the initial |+> state of the piecemaker qubit
    # @process init_piecemaker(sim, net, m)

    # Set up the entanglement trackers at each client
    trackers = [EntanglementTracker(sim, net, k) for k in 2:n+1]
    for tracker in trackers
        @process tracker()
    end

    # Set up an entanglement consumer between each unordered pair of clients
    consumer = GHZConsumer(net, net[1][m], event_ghz_state)
    @process consumer()

    # Finally, set up the switch without assignments
    switch_protocol = FusionSwitchDiscreteProt(net, 1, 2:n+1, fill(0.5, n))
    @process switch_protocol()

    
    
    return n, sim, consumer
end
