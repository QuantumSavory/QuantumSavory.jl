# For convenient graph data structures
using Graphs

# For discrete event simulation
using ResumableFunctions
using ConcurrentSim

# The workhorse for the simulation
using QuantumSavory
using QuantumSavory.StatesZoo

# Predefined useful circuits
using QuantumSavory.CircuitZoo: EntanglementSwap, Purify2to1

## Default simulation parameters (overridable)
const DEFAULT_PARAMS = (
    chain_length = 3,           # number of nodes in chain
    qubits_per_node = 3,        # memory qubits per node
    t2_dephasing = 10.0,        # T2 dephasing time
    entangler_rate = 0.5,       # entanglement attempts per time unit
    entangler_busy_time = 0.2,  # time to establish entanglement
    swapper_busy_time = 0.1,    # time to perform swap
    purifier_rate = 0.3,        # purification attempt rate
    purifier_busy_time = 0.15,  # time to perform purification
    fidelity_threshold = 0.75,  # purify when fidelity drops below this
    initial_fidelity = 0.92,    # initial fidelity of raw Bell pairs
    enable_adaptive = true,     # enable adaptive purification
)

"""Creates the datastructures representing the simulated network"""
function simulation_setup(;
    chain_length = DEFAULT_PARAMS.chain_length,
    qubits_per_node = DEFAULT_PARAMS.qubits_per_node,
    t2_dephasing = DEFAULT_PARAMS.t2_dephasing,
    representation = QuantumOpticsRepr,
    )

    # Create registers for each node in the chain
    registers = Register[]
    for i in 1:chain_length
        traits = [Qubit() for _ in 1:qubits_per_node]
        repr = [representation() for _ in 1:qubits_per_node]
        bg = [T2Dephasing(t2_dephasing) for _ in 1:qubits_per_node]
        push!(registers, Register(traits, repr, bg))
    end

    # Linear chain topology
    graph = path_graph(chain_length)
    network = RegisterNet(graph, registers)
    sim = get_time_tracker(network)

    # Initialize entanglement tracking per qubit
    for v in vertices(network)
        network[v, :enttrackers] = Any[nothing for i in 1:nsubsystems(network[v])]
        # Track fidelity of each Bell pair
        network[v, :fidelities] = Float64[0.0 for i in 1:nsubsystems(network[v])]
    end

    sim, network
end

"""Entanglement generator between adjacent nodes"""
@resumable function entangler(
    sim::Environment,
    network,
    nodea, nodeb,         # adjacent node pair
    noisy_pair_func,      # function that returns a noisy Bell pair state given fidelity
    entangler_busy_time,  # how long to establish entanglement
    entangler_wait_time,  # wait if all qubits busy
    )
    while true
        ia = findfreequbit(network, nodea)
        ib = findfreequbit(network, nodeb)
        if isnothing(ia) || isnothing(ib)
            @yield timeout(sim, entangler_wait_time)
            continue
        end
        slota = network[nodea, ia]
        slotb = network[nodeb, ib]
        @yield request(slota) & request(slotb)
        @yield timeout(sim, entangler_busy_time)

        registera = network[nodea]
        registerb = network[nodeb]
        # Create a Bell pair with the configured initial fidelity
        noisy_pair = noisy_pair_func(DEFAULT_PARAMS.initial_fidelity)
        initialize!((registera[ia], registerb[ib]), noisy_pair; time=now(sim))

        # Track who we're entangled with
        network[nodea, :enttrackers][ia] = (node=nodeb, slot=ib)
        network[nodeb, :enttrackers][ib] = (node=nodea, slot=ia)
        # Track current fidelity
        network[nodea, :fidelities][ia] = DEFAULT_PARAMS.initial_fidelity
        network[nodeb, :fidelities][ib] = DEFAULT_PARAMS.initial_fidelity

        @simlog sim "entangled node $nodea:$ia and node $nodeb:$ib (F=$(DEFAULT_PARAMS.initial_fidelity))"
        unlock(slota)
        unlock(slotb)
    end
end

"""Find an uninitialized unlocked qubit on a given node"""
function findfreequbit(network, node)
    register = network[node]
    regsize = nsubsystems(register)
    findfirst(i -> !isassigned(register, i) && !islocked(register[i]), 1:regsize)
end

"""Swapper that connects entanglement across a repeater node"""
@resumable function swapper(
    sim::Environment,
    network,
    node,                  # the middle node where we swap
    swapper_busy_time,     # how long the swap takes
    swapper_wait_time,     # wait if no swapable pairs
    )
    while true
        qubit_pair = findswapablequbits(network, node)
        if isnothing(qubit_pair)
            @yield timeout(sim, swapper_wait_time)
            continue
        end
        q1, q2 = qubit_pair
        @yield request(network[node][q1]) & request(network[node][q2])
        reg = network[node]

        # Identify the two remote nodes that these qubits connect to
        tracker_left = network[node, :enttrackers][q1]
        tracker_right = network[node, :enttrackers][q2]
        node_left = tracker_left.node
        node_right = tracker_right.node
        reg_left = network[node_left]
        reg_right = network[node_right]

        # Before swap: compute expected fidelity after swap
        f_left = network[node, :fidelities][q1]
        f_right = network[node, :fidelities][q2]
        # Entanglement swap reduces fidelity: F_swap ≈ F_left * F_right + (1-F_left)*(1-F_right)/3
        f_swap = f_left * f_right + (1 - f_left) * (1 - f_right) / 3.0

        @yield timeout(sim, swapper_busy_time)
        uptotime!((reg[q1], reg_left[tracker_left.slot], reg[q2], reg_right[tracker_right.slot]), now(sim))

        swapcircuit = EntanglementSwap()
        swapcircuit(reg[q1], reg_left[tracker_left.slot], reg[q2], reg_right[tracker_right.slot])

        # Update tracking after swap
        network[node_left, :enttrackers][tracker_left.slot] = (node=node_right, slot=tracker_right.slot)
        network[node_right, :enttrackers][tracker_right.slot] = (node=node_left, slot=tracker_left.slot)
        network[node_left, :fidelities][tracker_left.slot] = f_swap
        network[node_right, :fidelities][tracker_right.slot] = f_swap

        network[node, :enttrackers][q1] = nothing
        network[node, :enttrackers][q2] = nothing
        network[node, :fidelities][q1] = 0.0
        network[node, :fidelities][q2] = 0.0

        @simlog sim "swap at $node:$q1 & $q2 connecting $node_left and $node_right (F≈$f_swap)"
        unlock(network[node][q1])
        unlock(network[node][q2])
    end
end

function findswapablequbits(network, node)
    enttrackers = network[node, :enttrackers]
    left_nodes = [(i=i, n...) for (i, n) in enumerate(enttrackers)
                  if !isnothing(n) && n.node < node && !islocked(network[node][i])]
    isempty(left_nodes) && return nothing
    right_nodes = [(i=i, n...) for (i, n) in enumerate(enttrackers)
                   if !isnothing(n) && n.node > node && !islocked(network[node][i])]
    isempty(right_nodes) && return nothing
    _, farthest_left = findmin(n -> n.node, left_nodes)
    _, farthest_right = findmax(n -> n.node, right_nodes)
    return left_nodes[farthest_left].i, right_nodes[farthest_right].i
end

"""Adaptive purifier that checks fidelity before deciding to purify"""
@resumable function adaptive_purifier(
    sim::Environment,
    network,
    nodea, nodeb,             # the two nodes between which we purify
    purifier_busy_time,       # how long purification takes
    purifier_wait_time,       # wait if no pairs available
    fidelity_threshold,       # purify only when fidelity is below this
    )
    round = 0
    while true
        # Find pairs that are eligible for purification
        pairs = findqubitstopurify(network, nodea, nodeb)
        if isnothing(pairs)
            @yield timeout(sim, purifier_wait_time)
            continue
        end

        pair1qa, pair1qb, pair2qa, pair2qb = pairs
        f1 = network[nodea, :fidelities][pair1qa]
        f2 = network[nodea, :fidelities][pair2qa]

        # SKIP purification if both pairs already have good fidelity
        if DEFAULT_PARAMS.enable_adaptive && f1 > fidelity_threshold && f2 > fidelity_threshold
            @yield timeout(sim, purifier_wait_time)
            continue
        end

        locks = [network[nodea][[pair1qa, pair2qa]];
                 network[nodeb][[pair1qb, pair2qb]]]
        @yield mapreduce(request, &, locks)
        @yield timeout(sim, purifier_busy_time)

        rega = network[nodea]
        regb = network[nodeb]
        purifyerror = (:X, :Z)[round % 2 + 1]
        purificationcircuit = Purify2to1(purifyerror)
        success = purificationcircuit(rega[pair1qa], regb[pair1qb],
                                       rega[pair2qa], regb[pair2qb])

        if success
            round += 1
            # After successful purification, fidelity improves
            f_new = (f1 * f2) / (f1 * f2 + (1 - f1) * (1 - f2))
            network[nodea, :fidelities][pair1qa] = f_new
            network[nodeb, :fidelities][pair1qb] = f_new
            @simlog sim "purification SUCCESS at $nodea:$pair1qa & $nodeb:$pair1qb (F→$f_new)"
        else
            network[nodea, :enttrackers][pair1qa] = nothing
            network[nodeb, :enttrackers][pair1qb] = nothing
            network[nodea, :fidelities][pair1qa] = 0.0
            network[nodeb, :fidelities][pair1qb] = 0.0
            @simlog sim "purification FAILED at $nodea:$pair1qa"
        end

        # Sacrificed pair is always consumed
        network[nodea, :enttrackers][pair2qa] = nothing
        network[nodeb, :enttrackers][pair2qb] = nothing
        network[nodea, :fidelities][pair2qa] = 0.0
        network[nodeb, :fidelities][pair2qb] = 0.0
        release.(locks)
    end
end

function findqubitstopurify(network, nodea, nodeb)
    enttrackers_a = network[nodea, :enttrackers]
    rega = network[nodea]
    regb = network[nodeb]
    enttrackers = [(i=i, n...) for (i, n) in enumerate(enttrackers_a)
                   if !isnothing(n) && n.node == nodeb &&
                      !islocked(rega[i]) && !islocked(regb[n.slot])]
    if length(enttrackers) >= 2
        aqubits = [n.i for n in enttrackers[end-1:end]]
        bqubits = [n.slot for n in enttrackers[end-1:end]]
        return aqubits[2], bqubits[2], aqubits[1], bqubits[1]
    end
    return nothing
end

"""Estimate the current fidelity of a Bell pair from qubit state"""
function estimate_fidelity(register, slot, partner_register, partner_slot)
    if !isassigned(register, slot) || !isassigned(partner_register, partner_slot)
        return 0.0
    end
    # Compute fidelity against the ideal Bell state
    bell = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
    try
        state = (register[slot], partner_register[partner_slot])
        r = measure!([Z1⊗Z1, Z2⊗Z2, Z1⊗Z2, Z2⊗Z1]..., state; nshots=200)
        return 1.0 - sum(r[1:4]) / 400  # rough fidelity proxy
    catch
        return 0.0
    end
end

"""Build and return a complete simulation with all processes"""
function prepare_simulation(;
    chain_length = DEFAULT_PARAMS.chain_length,
    qubits_per_node = DEFAULT_PARAMS.qubits_per_node,
    t2_dephasing = DEFAULT_PARAMS.t2_dephasing,
    entangler_rate = DEFAULT_PARAMS.entangler_rate,
    entangler_busy_time = DEFAULT_PARAMS.entangler_busy_time,
    swapper_busy_time = DEFAULT_PARAMS.swapper_busy_time,
    purifier_rate = DEFAULT_PARAMS.purifier_rate,
    purifier_busy_time = DEFAULT_PARAMS.purifier_busy_time,
    fidelity_threshold = DEFAULT_PARAMS.fidelity_threshold,
    initial_fidelity = DEFAULT_PARAMS.initial_fidelity,
    enable_adaptive = DEFAULT_PARAMS.enable_adaptive,
    )

    # Override global params
    DEFAULT_PARAMS.initial_fidelity = initial_fidelity
    DEFAULT_PARAMS.enable_adaptive = enable_adaptive

    sim, network = simulation_setup(
        chain_length=chain_length,
        qubits_per_node=qubits_per_node,
        t2_dephasing=t2_dephasing
    )

    noisy_pair_func(F) = DepolarizedBellPair(; F)

    # Start entanglers between each adjacent pair
    entangler_wait_time = 1.0 / max(entangler_rate, 0.01)
    for i in 1:(chain_length - 1)
        @process entangler(sim, network, i, i + 1, noisy_pair_func,
                           entangler_busy_time, entangler_wait_time)
    end

    # Start swappers at intermediate nodes (nodes 2..n-1)
    swapper_wait_time = 0.05
    for i in 2:(chain_length - 1)
        @process swapper(sim, network, i, swapper_busy_time, swapper_wait_time)
    end

    # Start purifiers for end-to-end pairs
    purifier_wait_time = 1.0 / max(purifier_rate, 0.01)
    # Purify between node 1 and node 3 (after swapping)
    @process adaptive_purifier(sim, network, 1, chain_length,
                                purifier_busy_time, purifier_wait_time,
                                fidelity_threshold)

    return chain_length, sim, network
end
