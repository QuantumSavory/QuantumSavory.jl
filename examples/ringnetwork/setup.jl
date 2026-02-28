using QuantumSavory
using QuantumSavory.ProtocolZoo
using Graphs
using ConcurrentSim
using ResumableFunctions
using NetworkLayout

# Simulation setup for a ring network topology.
#
# Alice (node 1) and Bob (node N/2+1, on the opposite side of the ring)
# want to share entangled pairs. Entanglement can traverse either direction
# around the ring, providing path redundancy.

"""Prepare a ring network simulation.

Creates a cycle graph of `n` nodes with `regsize` memory slots per node.
Alice is node 1, Bob is node `n÷2+1` (diametrically opposite).
Entanglement can flow clockwise (1→2→...→bob) or counterclockwise (1→n→...→bob).

Returns the simulation handle, the network, graph, consumer, and tunable Observables.
"""
function prepare_simulation(;n=8, regsize=10, announce=true)
    alice = 1
    bob = n÷2 + 1

    graph = cycle_graph(n)
    net = RegisterNet(graph, [Register(regsize, T1Decay(10.0)) for _ in 1:n])
    sim = get_time_tracker(net)

    # Entanglement generation on each edge of the ring
    succ_prob = Observable(0.005)
    for (;src, dst) in edges(net)
        eprot = EntanglerProt(sim, net, src, dst;
            rounds=-1, randomize=true, success_prob=succ_prob[])
        @process eprot()
    end

    # Swap protocols at each intermediate node (all except Alice and Bob)
    local_busy_time = Observable(0.0)
    retry_lock_time = Observable(0.1)
    retention_time  = Observable(5.0)
    buffer_time     = Observable(0.5)

    for i in 1:n
        i == alice && continue
        i == bob   && continue
        low, high, cL, cH = ring_swap_predicates(i, n, alice, bob)
        swapper = SwapperProt(
            sim, net, i;
            nodeL=low, nodeH=high,
            chooseL=cL, chooseH=cH,
            rounds=-1, local_busy_time=local_busy_time[],
            retry_lock_time=retry_lock_time[],
            agelimit=announce ? nothing : retention_time[]-buffer_time[])
        @process swapper()
    end

    # Entanglement tracking at every node
    for v in vertices(net)
        tracker = EntanglementTracker(sim, net, v)
        @process tracker()
    end

    # Consumer between Alice and Bob
    period_cons = Observable(0.1)
    consumer = EntanglementConsumer(sim, net, alice, bob; period=period_cons[])
    @process consumer()

    # Cutoff protocol at each node for memory management
    period_dec = Observable(0.1)
    for v in vertices(net)
        decprot = CutoffProt(sim, net, v; announce, period=period_dec[])
        @process decprot()
    end

    return sim, net, graph, consumer,
        succ_prob, local_busy_time, retry_lock_time,
        retention_time, buffer_time, period_cons, period_dec
end

"""Compute swap predicates for a node in the ring network.

For a ring with Alice=1 and Bob=n÷2+1, each intermediate node needs
predicates that distinguish "toward Alice" from "toward Bob" on its
specific path around the ring.

Returns `(nodeL, nodeH, chooseL, chooseH)`.
"""
function ring_swap_predicates(node, n, alice, bob)
    if alice < node < bob
        # Clockwise path: alice → 2 → ... → node → ... → bob
        nodeL(x) = alice <= x < node
        nodeH(x) = node < x <= bob
        return nodeL, nodeH, argmin, argmax
    else
        # Counterclockwise path: alice → n → n-1 → ... → node → ... → bob
        nodeL(x) = x > node || x == alice
        nodeH(x) = bob <= x < node
        return nodeL, nodeH, argmin, argmin
    end
end
