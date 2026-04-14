# For convenient graph data structures
using Graphs

# For discrete event simulation
using ResumableFunctions
using ConcurrentSim

# Useful for interactive work
# Enables automatic re-compilation of modified codes
isinteractive() && @eval using Revise

# The workhorse for the simulation
using QuantumSavory

# Predefined useful circuits
using QuantumSavory.CircuitZoo: EntanglementSwap, Purify2to1
using QuantumSavory.ProtocolZoo: EntanglerProt, SwapperProt, EntanglementTracker, EntanglementCounterpart
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

    # The scheduler datastructure for the discrete event simulation
    sim = get_time_tracker(network)

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

##
# The Swapper
##


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
        pairs_of_bellpairs = findqubitstopurify(network, nodea, nodeb)
        if isnothing(pairs_of_bellpairs)
            @yield timeout(sim, purifier_wait_time)
            continue
        end
        # pairs_of_bellpairs = pairs_of_bellpairs::NTuple{4, QueryOnRegResult} # is this needed?
        qa1, qa2, qb1, qb2 = pairs_of_bellpairs
        @yield lock(qa1.slot) & lock(qa2.slot) & lock(qb1.slot) & lock(qb2.slot)
        @yield timeout(sim, purifier_busy_time)
        purifyerror = (:X, :Z)[round%2+1]
        purificationcircuit = Purify2to1(purifyerror)
        success = purificationcircuit(qa1.slot, qb1.slot, qa2.slot, qb2.slot)
        if !success
            untag!(qa1.slot, qa1.id)
            untag!(qb1.slot, qb1.id)
            @info sim "failed purification at $(nodea):$(qa1.slot.idx)&$(qa2.slot.idx) and $(nodeb):$(qb1.slot.idx)&$(qb2.slot.idx)"
        else
            round += 1
            @info "purification at $(nodea):$(qa1.slot.idx) $(nodeb):$(qb1.slot.idx) by sacrifice of $(nodea):$(qa2.slot.idx) $(nodeb):$(qb2.slot.idx)"
        end
        untag!(qa2.slot, qa2.id)
        untag!(qb2.slot, qb2.id)
        unlock(qa1.slot); unlock(qa2.slot); unlock(qb1.slot); unlock(qb2.slot)
    end
end

function findqubitstopurify(network, nodea, nodeb)
    rega = network[nodea]
    regb = network[nodeb]
    results_a = queryall(rega, EntanglementCounterpart, nodeb, ❓; locked=false, assigned=true)
    if length(results_a) >= 2
        qa1, qa2 = results_a[end-1], results_a[end]
        qb1 = query(regb, EntanglementCounterpart, nodea, qa1.slot.idx; locked=false, assigned=true)
        qb2 = query(regb, EntanglementCounterpart, nodea, qa2.slot.idx; locked=false, assigned=true)
        @assert !isnothing(qb1) && !isnothing(qb2)
        return qa1, qa2, qb1, qb2
    else
        return nothing
    end
end
