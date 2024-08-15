using QuantumSavory
using QuantumSavory.ProtocolZoo
using Graphs
using ConcurrentSim
using ResumableFunctions
using Distributions

"""A helper function to repeatedly make requests from a client to the switch to be connected to another client."""
@resumable function make_request(sim, net, client, other_client, rate_observable)
    while true
        wait_time = rand(Exponential(1/rate_observable[]))
        @yield timeout(sim, wait_time)
        put!(channel(net, client=>1), Tag(SwitchRequest(client, other_client)))
    end
end

function prepare_simulation()
    n = 10   # number of clients
    m = n-2 # memory slots in switch

    # The graph of network connectivity. Index 1 corresponds to the switch.
    graph = star_graph(n+1)

    switch_register = Register(m)
    client_registers = [Register(1) for _ in 1:n]
    net = RegisterNet(graph, [switch_register, client_registers...])
    sim = get_time_tracker(net)

    # Set up the request-making processes
    # between each ordered pair of clients
    client_pairs = [(k1,k2) for k1 in 2:n+1 for k2 in 2:n+1 if k2!=k1]
    rate_scale = 1/length(client_pairs)
    rates = [Ref(rate_scale) for _ in client_pairs]
    for ((client1, client2), rate) in zip(client_pairs, rates)
        @process make_request(sim, net, client1, client2, rate)
    end

    # Set up the entanglement trackers at each client
    trackers = [EntanglementTracker(sim, net, k) for k in 2:n+1]
    for tracker in trackers
        @process tracker()
    end

    # Set up an entanglement consumer between each unordered pair of clients
    client_unordered_pairs = [(k1,k2) for k1 in 2:n+1 for k2 in 2:n+1 if k2>k1]
    consumers = [EntanglementConsumer(net, k1, k2) for (k1,k2) in client_unordered_pairs]
    for consumer in consumers
        @process consumer()
    end

    # Finally, set up the switch
    switch_protocol = SimpleSwitchDiscreteProt(net, 1, 2:n+1, fill(0.4, n))
    @process switch_protocol()
    
    return n, sim, net, switch_protocol, client_pairs, client_unordered_pairs, consumers, rates, rate_scale
end
