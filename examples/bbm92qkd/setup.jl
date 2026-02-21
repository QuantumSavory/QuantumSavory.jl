using QuantumSavory
using QuantumSavory.ProtocolZoo
using Graphs
using ConcurrentSim
using ResumableFunctions

"""
    prepare_simulation(;n=4, regsize=10)

Set up a repeater chain of `n` nodes for BBM92 QKD.

Alice (node 1) and Bob (node n) perform BBM92 entanglement-based quantum key
distribution, with intermediate nodes acting as entanglement swappers. The
simulation returns observable parameters that can be adjusted via interactive
sliders.

Returns `(sim, net, graph, bbm92, succ_prob, local_busy_time, retry_lock_time,
retention_time, buffer_time, period_bbm92, period_dec)`.
"""
function prepare_simulation(;n=4, regsize=10)
    graph = grid([n])
    net = RegisterNet(graph, [Register(regsize, T1Decay(10.0)) for _ in 1:n])
    sim = get_time_tracker(net)

    # Entanglement generation on each edge
    succ_prob = Observable(0.005)
    for (;src, dst) in edges(net)
        eprot = EntanglerProt(sim, net, src, dst;
            rounds=-1, randomize=true, success_prob=succ_prob[])
        @process eprot()
    end

    # Entanglement swapping at intermediate nodes
    local_busy_time = Observable(0.0)
    retry_lock_time = Observable(0.1)
    retention_time  = Observable(5.0)
    buffer_time     = Observable(0.5)

    for v in 2:n-1
        sprot = SwapperProt(sim, net, v;
            nodeL = <(v), nodeH = >(v),
            chooseL = argmin, chooseH = argmax,
            rounds=-1,
            local_busy_time=local_busy_time[],
            retry_lock_time=retry_lock_time[],
            agelimit=retention_time[]-buffer_time[])
        @process sprot()
    end

    # Entanglement tracker at every node
    for v in vertices(net)
        tracker = EntanglementTracker(sim, net, v)
        @process tracker()
    end

    # BBM92 QKD protocol between Alice and Bob
    period_bbm92 = Observable(0.1)
    bbm92 = BBM92Prot(sim, net, 1, n; period=period_bbm92[])
    @process bbm92()

    # Cutoff protocol for qubit lifetime management
    period_dec = Observable(0.1)
    for v in vertices(net)
        decprot = CutoffProt(sim, net, v; period=period_dec[])
        @process decprot()
    end

    return sim, net, graph, bbm92,
        succ_prob, local_busy_time, retry_lock_time,
        retention_time, buffer_time, period_bbm92, period_dec
end
