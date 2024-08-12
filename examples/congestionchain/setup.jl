# For convenient graph data structures
using Graphs

# For probability distributions
using Distributions

# For discrete event simulation
using ResumableFunctions
using ConcurrentSim

# Useful for interactive work
# Enables automatic re-compilation of modified codes
using Revise

# The workhorse for the simulation
using QuantumSavory

# Predefined useful circuits
using QuantumSavory.CircuitZoo: EntanglementSwap

##
# Create a handful of qubit registers in a chain
##

"""Creates the datastructures representing the simulated network"""
function simulation_setup(
    length, # The length of the chain
    regsize, # The size of each register
    T2 # T2 dephasing times for the qubits
    ;
    representation = QuantumOpticsRepr # Representation to use for the qubits
    )

    # All of the quantum register we will be simulating
    registers = Register[]
    for _ in 1:length
        traits = [Qubit() for _ in 1:regsize]
        repr = [representation() for _ in 1:regsize]
        bg = [T2Dephasing(T2) for _ in 1:regsize]
        push!(registers, Register(traits,repr,bg))
    end

    # A graph structure defining the connectivity among registers
    # It is not necessary to use such a structure, however, it is a convenient way to
    # store data about the simulation (and we have created helper plotting functions
    # expecting such a structure).
    graph = grid([length])
    network = RegisterNet(graph, registers) # A graphs with extra "meta data"

    # A scheduler datastructure for the discrete event simulation
    sim = get_time_tracker(network)

    # Add a register datastructures and event locks to each node.
    for v in vertices(network)
        # Create an array specifying whether a qubit is entangled with another qubit
        network[v,:enttrackers] = Any[nothing for i in 1:length]
    end

    sim, network
end

##
# The Entangler
##

const perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
const perfect_pair_dm = SProjector(perfect_pair)
const mixed_dm = MixedState(perfect_pair_dm)
noisy_pair_func(F) = F*perfect_pair_dm + (1-F)*mixed_dm # TODO make a depolarization helper
const XX = X⊗X
const ZZ = Z⊗Z
const YY = Y⊗Y

@resumable function entangler(
    sim::Environment,   # The scheduler for all simulation events
    network,            # The graph of quantum nodes
    nodea, nodeb,       # The two nodes which we will be entangling
    noisy_pair,         # A raw entangled pair
    entangler_wait_time,# The wait time in case all qubits are "busy"
    entangler_busy_λ    # The λ parameter of the exp distribution of time to establish entanglement
    )
    while true
        ia = findfreequbit(network, nodea; constraint=:odd)
        ib = findfreequbit(network, nodeb; constraint=:even)
        if isnothing(ia) || isnothing(ib)
            @yield timeout(sim, entangler_wait_time)
            continue
        end
        slota = network[nodea,ia]
        slotb = network[nodeb,ib]
        @yield request(slota) & request(slotb)
        registera = network[nodea]
        registerb = network[nodeb]
        @yield timeout(sim, rand(Exponential(entangler_busy_λ)))
        initialize!((registera[ia],registerb[ib]),noisy_pair; time=now(sim))
        network[nodea,:enttrackers][ia] = (node=nodeb,slot=ib)
        network[nodeb,:enttrackers][ib] = (node=nodea,slot=ia)
        unlock(slota)
        unlock(slotb)
    end
end

"""Find an uninitialized unlocked qubit on a given node"""
function findfreequbit(network, node; constraint=nothing)
    register = network[node]
    regsize = nsubsystems(register)
    indices_to_check = if isnothing(constraint)
        1:regsize
    elseif constraint==:odd
        1:2:regsize
    elseif constraint==:even
        2:2:regsize
    end
    i = findfirst(i->!isassigned(register,i) & !islocked(register[i]), indices_to_check)
    return isnothing(i) ? nothing : indices_to_check[i]
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
        @yield request(network[node][q1]) & request(network[node][q2])
        reg = network[node]
        @yield timeout(sim, swapper_busy_time)
        node1 = network[node,:enttrackers][q1]
        reg1 = network[node1.node]
        node2 = network[node,:enttrackers][q2]
        reg2 = network[node2.node]
        uptotime!((reg[q1], reg1[node1.slot], reg[q2], reg2[node2.slot]), now(sim))
        swapcircuit(reg[q1], reg1[node1.slot], reg[q2], reg2[node2.slot])
        network[node1.node,:enttrackers][node1.slot] = node2
        network[node2.node,:enttrackers][node2.slot] = node1
        network[node,:enttrackers][q1] = nothing
        network[node,:enttrackers][q2] = nothing
        unlock(network[node][q1])
        unlock(network[node][q2])
    end
end

swapcircuit = EntanglementSwap()

function findswapablequbits(network,node)
    enttrackers = network[node,:enttrackers]
    left_nodes  = [(i=i,n...) for (i,n) in enumerate(enttrackers)
                   if !isnothing(n) && n.node<node && !islocked(network[node][i])]
    isempty(left_nodes)  && return nothing
    right_nodes = [(i=i,n...) for (i,n) in enumerate(enttrackers)
                   if !isnothing(n) && n.node>node && !islocked(network[node][i])]
    isempty(right_nodes) && return nothing
    _, farthest_left  = findmin(n->n.node, left_nodes)
    _, farthest_right = findmax(n->n.node, right_nodes)
    return left_nodes[farthest_left].i, right_nodes[farthest_right].i
end

##
# The Consumer
##

@resumable function consumer(
    sim::Environment, # The scheduler for all simulation events
    network,          # The graph of quantum nodes
    node1, node2,     # The nodes from which we try to consume
    consume_wait_time,# The wait time in case there are no available qubits for consuming
    timelog,          # A log of the times at which we consume
    fidelityXXlog,    # A log of the XX fidelities of the consumed pairs
    fidelityZZlog,    # A log of the ZZ fidelities of the consumed pairs
    )
    last_success = 0.0
    while true
        qubit_pair = findconsumablequbits(network,node1,node2)
        if isnothing(qubit_pair)
            @yield timeout(sim, consume_wait_time)
            continue
        end
        q1, q2 = qubit_pair
        reg1 = network[node1]
        reg2 = network[node2]
        @yield request(reg1[q1]) & request(reg2[q2])
        uptotime!((reg1[q1], reg2[q2]), now(sim))
        fXX = real(observable((reg1[q1],reg2[q2]), XX; something=0.0, time=now(sim)))
        fZZ = real(observable((reg1[q1],reg2[q2]), ZZ; something=0.0, time=now(sim)))
        push!(fidelityXXlog[], fXX)
        push!(fidelityZZlog[], fZZ)
        push!(timelog[], now(sim)-last_success)
        last_success = now(sim)
        traceout!(reg1[q1], reg2[q2])
        network[node1,:enttrackers][q1] = nothing
        network[node2,:enttrackers][q2] = nothing
        unlock(reg1[q1])
        unlock(reg2[q2])
    end
end

function findconsumablequbits(network,nodea,nodeb)
    enttrackers_a = network[nodea,:enttrackers]
    slots_a  = [(i=i,n...) for (i,n) in enumerate(enttrackers_a)
                if !isnothing(n) && n.node==nodeb && !islocked(network[nodea][i]) && !islocked(network[nodeb][n.slot])]
    isempty(slots_a)  && return nothing
    pair_to_be_consumed = first(slots_a)
    return pair_to_be_consumed.i, pair_to_be_consumed.slot
end
