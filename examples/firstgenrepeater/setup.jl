# For convenient graph data structures
using Graphs

# For discrete event simulation
using ResumableFunctions
using SimJulia

# The workhorse for the simulation
using Revise
using QuantumSavory

##
# Create a handful of qubit registers in a chain
##

"""Creates the datastructures representing the simulated network"""
function simulation_setup(
    sizes, # Array giving the number of qubits in each node
    T2 # T2 dephasing times for the qubits
    ;
    representation = QuantumOpticsRepr # Representation to use for the qubits
    )
    R = length(sizes) # Number of registers

    # A scheduler datastructure for the discrete event simulation
    sim = Simulation()

    # All of the quantum register we will be simulating
    registers = Register[]
    for s in sizes
        traits = [Qubit() for _ in 1:s]
        repr = [representation() for _ in 1:s]
        bg = [T2Dephasing(T2) for _ in 1:s]
        push!(registers, Register(traits,repr,bg))
    end

    # A graph structure defining the connectivity among registers
    # It is not necessary to use such a structure, however, it is a convenient way to
    # store data about the simulation (and we have created helper plotting functions
    # expecting such a structure).
    graph = grid([R])
    network = RegisterNet(graph, registers) # A graphs with extra "meta data"

    # Add a register datastructures and event locks to each node.
    for v in vertices(network)
        # Create an array specifying whether a qubit is entangled with another qubit
        network[v,:enttrackers] = Any[nothing for i in 1:sizes[v]]
        # Create an array of locks, telling us whether a qubit is undergoing an operation
        network[v,:locks] = [Resource(sim,1) for i in 1:sizes[v]]
    end

    sim, network
end

##
# The Entangler
##

const perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
const perfect_pair_dm = SProjector(perfect_pair)
const mixed_dm = MixedState(perfect_pair_dm)
noisy_pair_func(F) = F*perfect_pair_dm + (1-F)*mixed_dm
const XX = X⊗X
const ZZ = Z⊗Z
const YY = Y⊗Y

@resumable function entangler(
    sim::Environment,   # The scheduler for all simulation events
    network,            # The graph of quantum nodes
    nodea, nodeb,       # The two nodes which we will be entangling
    noisy_pair,         # A raw entangled pair
    entangler_wait_time,# The wait time in case all qubits are "busy"
    entangler_busy_time # How long it takes to establish entanglement
    )
    while true
        ia = findfreequbit(network, nodea)
        ib = findfreequbit(network, nodeb)
        if isnothing(ia) || isnothing(ib)
            @yield timeout(sim, entangler_wait_time)
            continue
        end
        locka = network[nodea,:locks][ia]
        lockb = network[nodeb,:locks][ib]
        @yield request(locka) & request(lockb)
        registera = network[nodea]
        registerb = network[nodeb]
        @yield timeout(sim, entangler_busy_time)
        initialize!((registera[ia],registerb[ib]),noisy_pair; time=now(sim))
        network[nodea,:enttrackers][ia] = (node=nodeb,slot=ib)
        network[nodeb,:enttrackers][ib] = (node=nodea,slot=ia)
        @simlog sim "entangled node $(nodea):$(ia) and node $(nodeb):$(ib)"
        release(locka)
        release(lockb)
    end
end

"""Find an uninitialized unlocked qubit on a given node"""
function findfreequbit(network, node)
    register = network[node]
    locks = network[node,:locks]
    regsize = nsubsystems(register)
    findfirst(i->!isassigned(register,i) & isfree(locks[i]), 1:regsize)
end

##
# The Swapper
##

@resumable function swapper(
    sim::Environment, # The scheduler for all simulation events
    network,          # The graph of quantum nodes
    node,             # The node on which the swapper works
    swapper_wait_time,# The wait time in case there are no available qubits for swapping
    swapper_busy_time # How long it takes to perform the swap
    )
    while true
        qubit_pair = findswapablequbits(network,node)
        if isnothing(qubit_pair)
            @yield timeout(sim, swapper_wait_time)
            continue
        end
        q1, q2 = qubit_pair
        locks = network[node, :locks][[q1,q2]]
        @yield mapreduce(request, &, locks)
        reg = network[node]
        @yield timeout(sim, swapper_busy_time)
        node1 = network[node,:enttrackers][q1]
        reg1 = network[node1.node]
        node2 = network[node,:enttrackers][q2]
        reg2 = network[node2.node]
        swapcircuit(reg[q1], reg[q2], reg1[node1.slot], reg2[node2.slot]; time=now(sim))
        network[node1.node,:enttrackers][node1.slot] = node2
        network[node2.node,:enttrackers][node2.slot] = node1
        network[node,:enttrackers][q1] = nothing
        network[node,:enttrackers][q2] = nothing
        @simlog sim "swap at $(node):$(q1)&$(q2) connecting $(node1) and $(node2)"
        release.(locks)
    end
end

function swapcircuit(localslot1, localslot2, remslot1, remslot2; time=nothing)
    apply!((localslot1, localslot2), CNOT; time=time)
    xmeas = project_traceout!(localslot1, σˣ)
    zmeas = project_traceout!(localslot2, σᶻ)
    if xmeas==2
        apply!(remslot1, Z)
    end
    if zmeas==2
        apply!(remslot2, X)
    end
end

function findswapablequbits(network,node)
    enttrackers = network[node,:enttrackers]
    locks = network[node,:locks]
    left_nodes  = [(i=i,n...) for (i,n) in enumerate(enttrackers)
                   if !isnothing(n) && n.node<node && isfree(locks[i])]
    isempty(left_nodes)  && return nothing
    right_nodes = [(i=i,n...) for (i,n) in enumerate(enttrackers)
                   if !isnothing(n) && n.node>node && isfree(locks[i])]
    isempty(right_nodes) && return nothing
    _, farthest_left  = findmin(n->n.node, left_nodes)
    _, farthest_right = findmax(n->n.node, right_nodes)
    return left_nodes[farthest_left].i, right_nodes[farthest_right].i
end

##
# The Purifier
##

@resumable function purifier(
    sim::Environment,  # The scheduler for all simulation events
    network,           # The graph of quantum nodes
    nodea,             # One of the nodes on which the pairs to be purified rest
    nodeb,             # The other such node
    purifier_wait_time,# The wait time in case there are no pairs available for purification
    purifier_busy_time # The duration of the purification circuit
    )
    round = 0
    while true
        pairs_of_bellpairs = findqubitstopurify(network,nodea,nodeb)
        if isnothing(pairs_of_bellpairs)
            @yield timeout(sim, purifier_wait_time)
            continue
        end
        pair1qa, pair1qb, pair2qa, pair2qb = pairs_of_bellpairs
        locks = [network[nodea,:locks][[pair1qa,pair2qa]];
                 network[nodeb,:locks][[pair1qb,pair2qb]]]
        @yield mapreduce(request, &, locks)
        @yield timeout(sim, purifier_busy_time)
        rega = network[nodea]
        regb = network[nodeb]
        gate = (CNOT, CPHASE)[round%2+1]
        apply!((rega[pair2qa],rega[pair1qa]),gate)
        apply!((regb[pair2qb],regb[pair1qb]),gate)
        measa = project_traceout!(rega[pair2qa], σˣ)
        measb = project_traceout!(regb[pair2qb], σˣ)
        if measa!=measb
            traceout!(rega[pair1qa])
            traceout!(regb[pair1qb])
            network[nodea,:enttrackers][pair1qa] = nothing
            network[nodeb,:enttrackers][pair1qb] = nothing
            @simlog sim "failed purification at $(nodea):$(pair1qa)&$(pair2qa) and $(nodeb):$(pair1qb)&$(pair2qb)"
        else
            round += 1
            @simlog sim "purification at $(nodea):$(pair1qa) $(nodeb):$(pair1qb) by sacrifice of $(nodea):$(pair1qa) $(nodeb):$(pair1qb)"
        end
        network[nodea,:enttrackers][pair2qa] = nothing
        network[nodeb,:enttrackers][pair2qb] = nothing
        release.(locks)
    end
end

function findqubitstopurify(network,nodea,nodeb)
    enttrackers = network[nodea,:enttrackers]
    locksa = network[nodea,:locks]
    locksb = network[nodeb,:locks]
    enttrackers = [(i=i,n...) for (i,n) in enumerate(enttrackers)
                   if !isnothing(n) && n.node==nodeb && isfree(locksa[i]) && isfree(locksb[n.slot])]
    if length(enttrackers)>=2
        aqubits = [n.i for n in enttrackers[end-1:end]]
        bqubits = [n.slot for n in enttrackers[end-1:end]]
        return aqubits[2], bqubits[2], aqubits[1], bqubits[1]
    else
        return nothing
    end
end
