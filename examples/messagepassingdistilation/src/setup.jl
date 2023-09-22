using Printf
using Crayons
using Crayons.Box
# For convenient graph data structures
using Graphs
# For discrete event simulation
using ResumableFunctions
using ConcurrentSim
import Base: put!, take!
# Useful for interactive work
# Enables automatic re-compilation of modified codes
using Revise
# The workhorse for the simulation
using QuantumSavory
# Predefined useful circuits
using QuantumSavory.CircuitZoo: EntanglementSwap, Purify2to1Node, Purify3to1Node, AbstractCircuit, inputqubits
# Clean messages
using SumTypes
# Random stuff
using Random, Distributions
Random.seed!(123)

const perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
const perfect_pair_dm = SProjector(perfect_pair)
const mixed_dm = MixedState(perfect_pair_dm)
noisy_pair_func(F) = F*perfect_pair_dm + (1-F)*mixed_dm

"""
    Structure that stores the parameters of the free qubit trigger protocol simulation.

    The parameters are chosen as such:
        - purifier_circuit: either Purify2to1Node or Purify3to1Node, meaning Simple and Double Selection respectively
        - loopsubtype: Loops through the sub-types of each circuit.
                        For example, single Selection has three subtypes: X, Y or Z
                        Double Selection has six: (X, Y), (Y, Z), (Z, X), (Y, X), (Z, Y) or (X, Z)
                        Defaults to [:X, :Y, :Z] meaning for single selection it will loop as such: X for the first generation,
                        Y for the second, Z for the third, and so on, and for the doubl selction it will loop as (X, Y) for the first gen,
                        then (Y, Z), then (Z, X), then back to (X, Y) and so on.

                        This parameter has been added to optimise fidelity growth, because when using two of the same
                        circuit subtypes, the resulting fidelity is lower as opposed to using two different ones consecutively.
                        This happens because of how fidelity pairs get generated as a probabilistic mix between a clean state and a mixed state with
                        equal probability for a X, Y, Z or no error.
        
        - waittime and busytime: Used to impose time delays on waiting actions or on actions that require busy time such as
                        entanglement generation.
        
        - keywords: this argument is a problematic one because it lacks abstraction. It defaults to `Dict(:simple_channel=>:fqtp_channel, :process_channel=>:fqtp_process_channel)`,
                        mening the keyword used for the `simple_channel` will be `fqtp_channel`, ad the keyword used for the `process_channel` will be `fqtp_process_channel`.
                        This is added because one might want to use some keywords for other features/traits in the network, and it would be 
                        bad if there would be no way to simply change the keywords attached to the channels used for this simulation.
                        
                        How do they work? `network[remotenode=>node, protocol.keywords[:simple_channel]]` is equivalent to 
                        network[remotenode=>node, :fqtp_channel], which returns the channel between `remotenode` and `node`.

        - emitonpurifsuccess: selects weather the already purified pairs can be used again
                        for purification. The protocol handles this option optimally, by only allowing a generation
                        of pairs to purify a pair of the same generation (we define a generation by the number of times
                        a pair has been purified). This parameter defaults to false, but should be set to true if
                        one wants to visualize a wider range of fidelities as they grow from generation to generation.

        - maxgeneration: (defaults to 10), limit to which pairs get recycled if emitonpurifsuccess option is enabled

"""
struct FreeQubitTriggerProtocolSimulation
    purifier_circuit
    loopsubtype
    waittime
    busytime
    keywords
    emitonpurifsuccess
    maxgeneration
end

"""
    Constructor equipped with default values.
"""
FreeQubitTriggerProtocolSimulation(circ;
                                    loopsubtype=[:X, :Y, :Z],
                                    waittime=0.4, busytime=0.3,
                                    keywords=Dict(:simple_channel=>:fqtp_channel, :process_channel=>:fqtp_process_channel),
                                    emitonpurifsuccess=false,
                                    maxgeneration=10) = FreeQubitTriggerProtocolSimulation(circ, loopsubtype, waittime, busytime, keywords, emitonpurifsuccess, maxgeneration)

#=
    Communication between nodes(registers) happens through Delayed Channels, and to each edge of the network
    are assigned two channels: 
        - a simple channel: used for message passing for small processes like unlocking/locking/ signalling a free qubit
    ready for entanglement, and 
        - a process channel: used for signalling more complex processes such as entanglement generation, purification and recycling

    SumTypes are used to be able to control the number of parameters a message has, as they ranfe from one to three,
    also using SumTypes, the patternmatching looks a lot cleaner and it's much easier to follow.

    The simple channel usually locks, unlocks or assigns slots to other slots. For more about why we
    make this split between simple and process channel check out ProcessMessage.
=#
@sum_type SimpleMessage begin
    mFIND_QUBIT_TO_PAIR(remote_i)
    mASSIGN_ORIGIN(remote_i, i)
    mINITIALIZE_STATE(remote_i, i)
    mLOCK(i)
    mUNLOCK(i)
    mGENERATED_ENTANGLEMENT(remote_i, i, generation)
end

#=
    Communication between nodes(registers) happens through Delayed Channels, and to each edge of the network
    are assigned two channels: 
        - a simple channel: used for message passing for small processes like unlocking/locking/ signalling a free qubit
    ready for entanglement, and 
        - a process channel: used for signalling more complex processes such as entanglement generation, purification and recycling

    This split and distinction between the two types of messages is done to facilitate performance and clean and easy to understand 
    message handling. Why is this beter than using a single channel? One simple example is the purification part of the protocol.
    For the purifier to activate, it needs to wait for at least two (or three) entangled pairs which takes time. Also the pairs could
    (in the future) be used not only for purification, but also for swapping and other processes, so it makes no sense to trigger the
    purification right after we received the wanted number of pairs.

    We need a listener that waits, reserves and decides to purify the pairs (if no other listener was faster than it), hence the process channel.
=#
@sum_type ProcessMessage begin
    mGENERATED_ENTANGLEMENT_REROUTED(remote_i, i, generation)
    mPURIFY(remote_measurement, indices, remoteindices, generation)
    mREPORT_SUCCESS(success , indices, remoteindices, generation)
end

"""
    This function finds a free qubit slot in a node (register), and it is used only
    by local nodes for themselves only.
"""
function findfreequbit(network, node)
    register = network[node]
    regsize = nsubsystems(register)
    findfirst(i->!isassigned(register, i) && !islocked(register[i]), 1:regsize)
end

"""
    Sets up the simulation based on the config parameters received through the FreeQubitTriggerProtocolSimulation
    structure.
"""
function simulation_setup(sizes, commtimes, protocol::FreeQubitTriggerProtocolSimulation)
    registers = Register[]
    for s in sizes
        push!(registers, Register(s))
    end

    graph = grid([length(sizes)])
    network = RegisterNet(graph, registers)
    sim = get_time_tracker(network)

    # Set up the all channels communicating between nodes
    for (;src, dst) in edges(network)
        network[src=>dst, protocol.keywords[:simple_channel]] = DelayQueue(sim, commtimes[1])
        network[dst=>src, protocol.keywords[:simple_channel]] = DelayQueue(sim, commtimes[2])
    end

    # Set up the all channels that communicate when an action was finished: e.g. entanglemnt/purifiation
    for (;src, dst) in edges(network)
        network[src=>dst, protocol.keywords[:process_channel]] = DelayQueue(sim, commtimes[1])
        network[dst=>src, protocol.keywords[:process_channel]] = DelayQueue(sim, commtimes[2])
    end
    
    for v in vertices(network)
        # Create an array specifying whether a qubit is entangled with another qubit
        network[v,:enttrackers] = Any[nothing for i in 1:sizes[v]]
    end

    sim, network
end
"""
    The trigger which triggers the entanglement start e.g. a free qubit is found.
    
    This function is attached to a single node from every edge. We do this to overcome message overflows
    or endles locking of resources.

    An edge of the graph would look like this:
        
        A ------- B
    
    WLOG, we can take each edge of a given graph and turn it into a directed edge at random.
        
        A ------> B
    
    After that we choose the node A and add the free_qubittrigger process to it. Thus A will signal to
    B when it finds an unlocked qubit and is ready to entangle it, but B will not signal to A, but instead 
    wait for A's signal.

    Why only attach the trigger to A? 
    If we attach the trigger to both A and B the following will happen, if A and B have only one available slot:
        
    Time 0:
        - A finds free qubit slot 1 and locks it and signals to B
        - B finds free qubit slot 1 and locks it and signals to A
    Time 1:
        - B receives message fro A, but has no unlocked slots, so it does nothing
        - Same with A.
    
    So we reach a standing position from which we can no longer continue, even though A and B both have a free slot
    
"""
@resumable function freequbit_trigger(sim::Simulation, protocol::FreeQubitTriggerProtocolSimulation, network, node, remotenode, logfile=nothing)
    waittime = protocol.waittime
    busytime = protocol.busytime    
    channel = network[node=>remotenode, protocol.keywords[:simple_channel]]
    remote_channel = network[remotenode=>node, protocol.keywords[:simple_channel]]
    while true
        slog!(logfile, "$(now(sim)) :: $node > Searching for freequbit in $node", "")

        i = findfreequbit(network, node)
        if isnothing(i)
            @yield timeout(sim, waittime)
            continue
        end

        @yield request(network[node][i])
        slog!(logfile, "$(now(sim)) :: $node > Entanglement process is triggered! Found and Locked $(node):$(i). Requesting pair...", "$node:$i")
        @yield timeout(sim, busytime)
        put!(channel, mFIND_QUBIT_TO_PAIR(i))
    end
end

"""
    The entangle process, handles (mostly) the simple channel, and attaches listeners for 6 types of messages:
        
        - mFIND_QUBIT_TO_PAIR : finds a qubit after a trigger signal has been received from the freequbit_trigger process
        - mASSIGN_ORIGIN : assigns original qubit to it's found pair and sends a message to initialize the state
        - mINITIALIZE_STATE : entangles the qubits locally and then sends one back to the slot (the qubit sending part is not written in code but is implied). After that a message is sent 
        that entanglement has been generated.
        - mGENERATED_ENTANGLEMENT : entanglement is generated and rerouted to the process channel which waits for more pairs to perform purification
        - mUNLOCK and mLOCK : sent when a node wants to unlock another remote node's slot

    This process is added to both nodes from each edge.
    Check out the README.md file to see the exact chronology of events.
"""
@resumable function entangle(sim::Simulation, protocol::FreeQubitTriggerProtocolSimulation, network, node, remotenode, noisy_pair = noisy_pair_func(0.7)
    , logfile=nothing, sampledentangledtimes=[false], entangletimedist=Exponential(0.4))
    waittime = protocol.waittime
    busytime = protocol.busytime
    channel = network[node=>remotenode, protocol.keywords[:simple_channel]]
    remote_channel = network[remotenode=>node, protocol.keywords[:simple_channel]]
    while true
        message = @yield take!(remote_channel)        
        @cases message begin
            mFIND_QUBIT_TO_PAIR(remote_i) => begin
                i = findfreequbit(network, node)
                if isnothing(i)
                    slog!(logfile, "$(now(sim)) :: $node > Nothing found at $node per request of $remotenode. Requested the unlocking of $remotenode:$remote_i", "$remotenode:$remote_i")
                    put!(channel, mUNLOCK(remote_i))
                else
                    @yield request(network[node][i])
                    @yield timeout(sim, busytime)
                    network[node,:enttrackers][i] = (remotenode,remote_i)
                    put!(channel, mASSIGN_ORIGIN(i, remote_i))
                end
            end
            
            mASSIGN_ORIGIN(remote_i, i) => begin
                slog!(logfile, "$(now(sim)) :: $node > Pair found! Pairing $node:$i, $remotenode:$remote_i ...", "$node:$i $remotenode:$remote_i")
                network[node,:enttrackers][i] = (remotenode,remote_i)
                put!(channel, mINITIALIZE_STATE(i, remote_i))
            end
            
            mINITIALIZE_STATE(remote_i, i) => begin
                slog!(logfile, "$(now(sim)) :: $node > Waiting on entanglement generation between $node:$i and $remotenode:$remote_i ...", "$node:$i $remotenode:$remote_i")
                entangletime = rand(entangletimedist)
                @yield timeout(sim, entangletime)
                (sampledentangledtimes[1] != false) && (push!(sampledentangledtimes[1][], entangletime))
                initialize!((network[node][i], network[remotenode][remote_i]),noisy_pair; time=now(sim))
                slog!(logfile, "$(now(sim)) :: $node > Success! $node:$i and $remotenode:$remote_i are now entangled.", "$node:$i $remotenode:$remote_i")
                unlock(network[node][i])
                put!(channel, mUNLOCK(remote_i))
                # signal that entanglement got generated
                put!(channel, mGENERATED_ENTANGLEMENT(i, remote_i, 1))
            end
            
            mGENERATED_ENTANGLEMENT(remote_i, i, generation) => begin
                process_channel = network[node=>remotenode, protocol.keywords[:process_channel]]
                # reroute the message to the process channel
                put!(process_channel, mGENERATED_ENTANGLEMENT_REROUTED(i, remote_i, generation))
            end

            mUNLOCK(i) => begin
                unlock(network[node][i])
                slog!(logfile, "$(now(sim)) :: $node > Unlocked $node:$i \n", "$node:$i")
                @yield timeout(sim, waittime)
            end

            mLOCK(i) => begin
                @yield request(network[node][i])
                slog!(logfile, "$(now(sim)) :: $node > Locked $node:$i \n", "$node:$i")
                @yield timeout(sim, busytime)
            end
        end
    end
end

"""
    The purifier listens on the process chanel for enough entangled pairs to get started on purification.
    It handles 3 types of messages all involving the same generation of pairs to improve fidelity.

        - mGENERATED_ENTANGLEMENT_REROUTED : entanglement has been generated
        - mPURIFY : enough pairs detected, purification is performed and reported
        - mREPORT_SUCCESS : if sucesfull, entanglement is either recycled or kept (based on the emitonpurifsuccess option), if not
                            unlocking of the destroyed pairs is requested as they will await entanglement once again.

    Generations are defined by the times a pair has been purified, and it's necesary to be keep them because
    different generations will be purified with different subtypes of the chosen purif circuit. This is done to prevent

    The way we build pairs with a given fidelity is as such: F*clean_state + (1-F)*mixed_state, where F is the fidelity,
    and mixed_state is the result of an equal probability state of 4 errors: X, Y, Z, and I (no error). As different subtypes
    of the 2to1, or 3to1 fix different kinds of errors, it makes sense that among different generations we use different subtypes
    to detect as much errors as possible.
"""
@resumable function purifier(sim::Simulation, protocol::FreeQubitTriggerProtocolSimulation, network, node, remotenode, logfile=nothing)
    waittime = protocol.waittime
    busytime = protocol.busytime
    emitonpurifsuccess = protocol.emitonpurifsuccess
    maxgeneration = protocol.maxgeneration

    channel = network[node=>remotenode, protocol.keywords[:simple_channel]]
    remote_channel = network[remotenode=>node, protocol.keywords[:simple_channel]]

    process_channel = network[node=>remotenode, protocol.keywords[:process_channel]]
    remote_process_channel = network[remotenode=>node, protocol.keywords[:process_channel]]
    
    indicesg = []     
    remoteindicesg = []
    for _ in 1:maxgeneration
        push!(indicesg, [])
        push!(remoteindicesg, [])
    end
    purif_circuit_size = inputqubits(protocol.purifier_circuit())
    while true
        message = @yield take!(remote_process_channel)
        @cases message begin
            mGENERATED_ENTANGLEMENT_REROUTED(remote_i, i, generation) => begin
                push!(indicesg[generation], i)
                push!(remoteindicesg[generation], remote_i)
                @yield request(network[node][i])
                @yield timeout(sim, busytime)
                put!(channel, mLOCK(remote_i))

                slog!(logfile, "$(now(sim)) :: $node > Locked $node:$i, $remotenode:$remote_i. Awaiting for purificaiton. Indices Queue: $(indicesg[generation]), $(remoteindicesg[generation]). Generation #$generation", "$node:$i $remotenode:$remote_i")

                if length(indicesg[generation]) == purif_circuit_size
                    slog!(logfile, "$(now(sim)) :: $node > Purification process triggered for: $node:$(indicesg[generation]), $remotenode:$(remoteindicesg[generation]). Preparing for purification...", 
                                        join(["$node:$(x)" for x in indicesg[generation]], " ")*" "*join(["$remotenode:$(x)" for x in remoteindicesg[generation]], " ") )
                    # begin purification of self
                    @yield timeout(sim, busytime)

                    slots = [network[node][x] for x in indicesg[generation]]
                    type = [protocol.loopsubtype[(generation + i - 1) % length(protocol.loopsubtype) + 1] for i in 1:inputqubits(protocol.purifier_circuit())-1]
                    local_measurement = protocol.purifier_circuit(type...)(slots...)
                    # send message to other node to apply purif side of circuit
                    put!(process_channel, mPURIFY(local_measurement, remoteindicesg[generation], indicesg[generation], generation))
                    indicesg[generation] = []
                    remoteindicesg[generation] = []
                end
            end

            mPURIFY(remote_measurement, indices, remoteindices, generation) => begin
                slots = [network[node][x] for x in indices]
                @yield timeout(sim, busytime)
                type = [protocol.loopsubtype[(generation + i - 1) % length(protocol.loopsubtype) + 1] for i in 1:inputqubits(protocol.purifier_circuit())-1]
                local_measurement = protocol.purifier_circuit(type...)(slots...)
                success = local_measurement == remote_measurement
                put!(process_channel, mREPORT_SUCCESS(success, remoteindices, indices, generation))
                if !success
                    slog!(logfile, "$(now(sim)) :: $node :: destroyed > Purification failed @ $node:$indices, $remotenode:$remoteindices",
                                            join(["$node:$(x)" for x in indices], " ")*" "*join(["$remotenode:$(x)" for x in remoteindices], " "))
                    traceout!(network[node][indices[1]])
                    network[node,:enttrackers][indices[1]] = nothing
                else
                    slog!(logfile, "$(now(sim)) :: $node > Purification succeded @ $node:$indices, $remotenode:$remoteindices\n",
                                            join(["$node:$(x)" for x in indices], " ")*" "*join(["$remotenode:$(x)" for x in remoteindices], " "))
                    slog!(logfile, "$(now(sim)) :: $node :: destroyed > Sacrificed @ $node:$(indices[2:end]), $remotenode:$(remoteindices[2:end])\n",
                                            join(["$node:$(x)" for x in indices[2:end]], " ")*" "*join(["$remotenode:$(x)" for x in remoteindices[2:end]], " "))
                end
                (network[node,:enttrackers][indices[i]] = nothing for i in 2:purif_circuit_size)
                unlock.(network[node][indices])
            end

            mREPORT_SUCCESS(success, indices, remoteindices, generation) => begin
                if !success
                    traceout!(network[node][indices[1]])
                    network[node,:enttrackers][indices[1]] = nothing
                end
                (network[node,:enttrackers][indices[i]] = nothing for i in 2:purif_circuit_size)
                unlock.(network[node][indices])
                if emitonpurifsuccess && success && generation+1 <= maxgeneration
                    @yield timeout(sim, busytime)
                    put!(channel, mGENERATED_ENTANGLEMENT(indices[1], remoteindices[1], generation+1)) # emit ready for purification and increase generation
                end
            end
        end
    end
end
