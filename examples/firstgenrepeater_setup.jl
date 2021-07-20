# For plotting
using GLMakie

# For convenient graph data structures
using Graphs
using MetaGraphs

# For discrete event simulation
using ResumableFunctions
using SimJulia

# For statistical distributions
using Distributions

# Low-level simulation tools that are mostly not necessary
using QuantumOptics
#using QuantumClifford # We will not use Clifford Simulations here

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
    )
    R = length(sizes) # Number of registers

    # A scheduler datastructure for the discrete event simulation
    sim = Simulation()

    # A graph structure defining the connectivity among registers
    # It is not necessary to use such a structure, however, it is a convenient way to
    # store data about the simulation (and we have created helper plotting functions
    # expecting such a structure).
    _graph = grid([R])
    mgraph = MetaGraph(_graph) # Meta graphs can contain extra meta information

    # Add a register datastructures and event locks to each node.
    for v in vertices(mgraph)
        # Create and store a qubit register at each node
        lay = Layout([QubitTrait() for i in 1:sizes[v]])
        bg = [T2Dephasing(T2) for i in 1:sizes[v]]
        set_prop!(mgraph, v,
            :register,
            Register(lay,bg,Symbol(v)))
        # Create an array specifying wheater a qubit is entangled with another qubit
        set_prop!(mgraph, v,
            :enttrackers,
            Any[nothing for i in 1:sizes[v]])
        # Create an array of locks, telling us whether a qubit is undergoing an operation
        set_prop!(mgraph, v,
            :locks,
            [Resource(sim,1) for i in 1:sizes[v]])
    end

    sim, mgraph
end

##
# The Entangler
##

# Using QuantumOptics.jl to create a noisy Bell pair object,
# in density matrix representation.
b = SpinBasis(1//2)
l = spindown(b)
h = spinup(b)
perfect_pair = (l⊗l + h⊗h)/sqrt(2)
const perfect_pair_dm = dm(perfect_pair)
const mixed = identityoperator(basis(perfect_pair))/4
function noisy_pair(F)
    F*perfect_pair_dm + (1-F)*mixed
end
const XX = sigmax(b)⊗sigmax(b)
const ZZ = sigmaz(b)⊗sigmaz(b)
const YY = sigmay(b)⊗sigmay(b)

@resumable function entangler(
    sim::Environment,   # The scheduler for all simulation events
    mgraph,             # The graph of qubit nodes
    nodea, nodeb,       # The two nodes which we will be entangling
    F,                  # The raw entanglement fidelity
    entangler_wait_time,# The wait time in case all qubits are "busy"
    entangler_busy_time # How long it takes to establish entanglement
    )
    while true
        ia = findfreequbit(mgraph, nodea)
        ib = findfreequbit(mgraph, nodeb)
        if isnothing(ia) || isnothing(ib)
            @yield timeout(sim, entangler_wait_time)
            continue
        end
        locka = get_prop(mgraph,nodea,:locks)[ia]
        lockb = get_prop(mgraph,nodeb,:locks)[ib]
        @yield request(locka) & request(lockb)
        registera = get_prop(mgraph,nodea,:register)
        registerb = get_prop(mgraph,nodeb,:register)
        @yield timeout(sim, entangler_busy_time)
        initialize!([registera,registerb],[ia,ib],noisy_pair(F); time=now(sim))
        get_prop(mgraph,nodea,:enttrackers)[ia] = (node=nodeb,slot=ib)
        get_prop(mgraph,nodeb,:enttrackers)[ib] = (node=nodea,slot=ia)
        @simlog sim "entangled node $(nodea):$(ia) and node $(nodeb):$(ib)"
        release(locka)
        release(lockb)
    end
end

"""Find an uninitialized unlocked qubit on a given node"""
function findfreequbit(mgraph, node)
    register = get_prop(mgraph,node,:register)
    locks = get_prop(mgraph,node,:locks)
    regsize = nsubsystems(register)
    findfirst(i->!isassigned(register,i) & isfree(locks[i]), 1:regsize)
end

##
# The Swapper
##

@resumable function swapper(
    sim::Environment, # The scheduler for all simulation events
    mgraph,           # The graph of qubit nodes
    node,             # The node on which the swapper works
    swapper_wait_time,# The wait time in case there are no available qubits for swapping
    swapper_busy_time # How long it takes to perform the swap
    )
    while true
        qubit_pair = findswapablequbits(mgraph,node)
        if isnothing(qubit_pair)
            @yield timeout(sim, swapper_wait_time)
            continue
        end
        q1, q2 = qubit_pair
        locks = get_prop(mgraph, node, :locks)[[q1,q2]]
        @yield mapreduce(request, &, locks)
        reg = get_prop(mgraph, node, :register)
        @yield timeout(sim, swapper_busy_time)
        apply!([reg,reg], [q1,q2], Gates.CNOT; time=now(sim))
        xmeas = project_traceout!(reg, q1, [States.X₀, States.X₁])
        zmeas = project_traceout!(reg, q2, [States.Z₀, States.Z₁])
        node1 = get_prop(mgraph,node,:enttrackers)[q1]
        reg1 = get_prop(mgraph,node1.node,:register)
        if xmeas==2
            apply!([reg1], [node1.slot], Gates.Z)
        end
        node2 = get_prop(mgraph,node,:enttrackers)[q2]
        reg2 = get_prop(mgraph,node2.node,:register)
        if zmeas==2
            apply!([reg2], [node2.slot], Gates.X)
        end
        get_prop(mgraph,node1.node,:enttrackers)[node1.slot] = node2
        get_prop(mgraph,node2.node,:enttrackers)[node2.slot] = node1
        get_prop(mgraph,node,:enttrackers)[q1] = nothing
        get_prop(mgraph,node,:enttrackers)[q2] = nothing
        @simlog sim "swap at $(node):$(q1)&$(q2) connecting $(node1) and $(node2)"
        release.(locks)
    end
end

function findswapablequbits(mgraph,node)
    enttrackers = get_prop(mgraph,node,:enttrackers)
    locks = get_prop(mgraph,node,:locks)
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
    mgraph,            # The graph of qubit nodes
    nodea,             # One of the nodes on which the pairs to be purified rest
    nodeb,             # The other such node
    purifier_wait_time,# The wait time in case there are no pairs available for purification
    purifier_busy_time # The duration of the purification circuit
    )
    round = 0
    while true
        pairs_of_bellpairs = findqubitstopurify(mgraph,nodea,nodeb)
        if isnothing(pairs_of_bellpairs)
            @yield timeout(sim, purifier_wait_time)
            continue
        end
        pair1qa, pair1qb, pair2qa, pair2qb = pairs_of_bellpairs
        locks = [get_prop(mgraph,nodea,:locks)[[pair1qa,pair2qa]];
                 get_prop(mgraph,nodeb,:locks)[[pair1qb,pair2qb]]]
        @yield mapreduce(request, &, locks)
        @yield timeout(sim, purifier_busy_time)
        rega = get_prop(mgraph,nodea,:register)
        regb = get_prop(mgraph,nodeb,:register)
        println((nodea,nodeb),(pair1qa, pair1qb, pair2qa, pair2qb))
        gate = (Gates.CNOT, Gates.CPHASE)[round%2+1]
        apply!([rega,rega],[pair2qa,pair1qa],gate)
        apply!([regb,regb],[pair2qb,pair1qb],gate)
        measbasis = [States.X₀, States.X₁]
        measa = project_traceout!(rega, pair2qa, measbasis)
        measb = project_traceout!(regb, pair2qb, measbasis)
        if measa!=measb
            traceout!(rega, pair1qa)
            traceout!(regb, pair1qb)
            get_prop(mgraph,nodea,:enttrackers)[pair1qa] = nothing
            get_prop(mgraph,nodeb,:enttrackers)[pair1qb] = nothing
            @simlog sim "failed purification at $(nodea):$(pair1qa)&$(pair2qa) and $(nodeb):$(pair1qb)&$(pair2qb)"
        else
            round += 1
            @simlog sim "purification at $(nodea):$(pair1qa) $(nodeb):$(pair1qb) by sacrifice of $(nodea):$(pair1qa) $(nodeb):$(pair1qb)"
        end
        get_prop(mgraph,nodea,:enttrackers)[pair2qa] = nothing
        get_prop(mgraph,nodeb,:enttrackers)[pair2qb] = nothing
        release.(locks)
    end
end

function findqubitstopurify(mgraph,nodea,nodeb)
    enttrackers = get_prop(mgraph,nodea,:enttrackers)
    locksa = get_prop(mgraph,nodea,:locks)
    locksb = get_prop(mgraph,nodeb,:locks)
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
