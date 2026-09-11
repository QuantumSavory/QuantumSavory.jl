# Butterfly Network Topology Setup
# Implements a 6-node butterfly network for studying quantum network coding
# vs classical routing bottlenecks.
#
# Nodes:
#   1: S1 (Source 1)
#   2: S2 (Source 2)
#   3: A  (Router 1)
#   4: B  (Router 2)
#   5: T1 (Sink 1)
#   6: T2 (Sink 2)

using Graphs
using Distributions
using ResumableFunctions
using ConcurrentSim
using QuantumSavory
using QuantumSavory.StatesZoo
using QuantumSavory.CircuitZoo: EntanglementSwap

"""Creates the datastructures for the 6-node butterfly network."""
function simulation_setup(;
    regsize = 4,
    T2 = 100.0,
    representation = QuantumOpticsRepr
)
    registers = Register[]
    for _ in 1:6
        traits = [Qubit() for _ in 1:regsize]
        repr = [representation() for _ in 1:regsize]
        bg = [T2Dephasing(T2) for _ in 1:regsize]
        push!(registers, Register(traits, repr, bg))
    end

    # Butterfly topology (7 edges)
    graph = SimpleGraph(6)
    add_edge!(graph, 1, 3) # S1 - A
    add_edge!(graph, 2, 3) # S2 - A
    add_edge!(graph, 3, 4) # A - B (central link)
    add_edge!(graph, 4, 5) # B - T1
    add_edge!(graph, 4, 6) # B - T2
    add_edge!(graph, 1, 5) # S1 - T1 (direct)
    add_edge!(graph, 2, 6) # S2 - T2 (direct)
    
    network = RegisterNet(graph, registers)
    sim = get_time_tracker(network)

    for v in vertices(network)
        network[v,:enttrackers] = Any[nothing for i in 1:regsize]
    end

    sim, network
end

noisy_pair_func(F) = DepolarizedBellPair(;F)

@resumable function entangler(
    sim::Environment,
    network,
    nodea, nodeb,
    noisy_pair,
    entangler_wait_time,
    entangler_busy_λ
)
    while true
        ia = findfreequbit(network, nodea)
        ib = findfreequbit(network, nodeb)
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

function findfreequbit(network, node)
    register = network[node]
    regsize = nsubsystems(register)
    i = findfirst(i->!isassigned(register,i) & !islocked(register[i]), 1:regsize)
    return isnothing(i) ? nothing : i
end

@resumable function swapper(
    sim::Environment,
    network,
    node,
    swapper_wait_time,
    swapper_busy_time,
    mode
)
    while true
        qubit_pair = findswapablequbits(network, node, mode)
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
        
        swapcircuit = EntanglementSwap()
        swapcircuit(reg[q1], reg1[node1.slot], reg[q2], reg2[node2.slot])
        
        network[node1.node,:enttrackers][node1.slot] = (node=node2.node, slot=node2.slot)
        network[node2.node,:enttrackers][node2.slot] = (node=node1.node, slot=node1.slot)
        network[node,:enttrackers][q1] = nothing
        network[node,:enttrackers][q2] = nothing
        unlock(network[node][q1])
        unlock(network[node][q2])
    end
end

function findswapablequbits(network, node, mode)
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

@resumable function consumer(
    sim::Environment,
    network,
    node1, node2,
    consume_wait_time,
    timelog,
    fidelityXXlog,
    fidelityZZlog
)
    last_success = 0.0
    const XX = X⊗X
    const ZZ = Z⊗Z
    while true
        qubit_pair = findconsumablequbits(network, node1, node2)
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

function findconsumablequbits(network, nodea, nodeb)
    enttrackers_a = network[nodea,:enttrackers]
    slots_a  = [(i=i,n...) for (i,n) in enumerate(enttrackers_a)
                if !isnothing(n) && n.node==nodeb && !islocked(network[nodea][i]) && !islocked(network[nodeb][n.slot])]
    isempty(slots_a)  && return nothing
    pair_to_be_consumed = first(slots_a)
    return pair_to_be_consumed.i, pair_to_be_consumed.slot
end
