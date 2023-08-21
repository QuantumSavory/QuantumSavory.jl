# Colored writing for console log
using Printf
Base.show(io::IO, f::Float16) = print(io, (@sprintf("%.3f",f)))
Base.show(io::IO, f::Float64) = print(io, (@sprintf("%.3f",f)))
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
using QuantumSavory.CircuitZoo: EntanglementSwap, Purify2to1
using SumTypes

const perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
const perfect_pair_dm = SProjector(perfect_pair)
const mixed_dm = MixedState(perfect_pair_dm)
noisy_pair_func(F) = F*perfect_pair_dm + (1-F)*mixed_dm # TODO make a depolarization helper

struct FreeQubitTriggerProtocolSimulation # todo find name for it :). Should i just use normal params in the processes and get rid of this?
    purifier_circuit_size
    purifier_circuit
    waittime
    busytime
    keywords
    emitonpurifsuccess
    maxgeneration
end

function slog!(s, msg)
    if s === nothing
        println(msg)
        return
    end
    signature,message = split(msg, ">"; limit=2)
    time=  getfirstfloat(signature)
    el = DOM.div(DOM.span(replace(signature * " | ", "\"" => ""), style="color: cyan;"), DOM.span(replace(message, "\"" => "")), DOM.br(), class="console_line", id="console_line_$(time)_$(length(s[]))_$(rand())")
    s[] = append!(s[], [el]) 
    notify(s)
end

function getfirstfloat(s)
    for el in split(s, " ")
        if tryparse(Float64, el) !== nothing
            return parse(Float64, el)
        end
    end
end

#=
    https://github.com/MasonProtter/SumTypes.jl
    We have 2 types of channels:
        - normal channels (which perform basic operations)
        - process channels (which need more than just qubits to perform actions)

    The structure of a message on the normal channels is as such
        | send      => channel        (MESSAGE_ID, index, remote_index)
        | receive   => remote_channel (MESSAGE_ID, remote_index, index)

    On the process channel we have (except on the message connecting the 2 types of channels)
        | send      => process_channel (MESSAGE_ID, variable, [remote_indices, indices])
        | receive   => remote_process_channel (MESSAGE_ID, variable, [indices, remote_indices])
=#
@sum_type SimpleMessage begin
    mFIND_QUBIT_TO_PAIR(remote_i)
    mASSIGN_ORIGIN(remote_i, i)
    mINITIALIZE_STATE(remote_i, i)
    mLOCK(i)
    mUNLOCK(i)
    mGENERATED_ENTANGLEMENT(remote_i, i, generation)
end

@sum_type ProcessMessage begin
    mGENERATED_ENTANGLEMENT_REROUTED(remote_i, i, generation)
    mPURIFY(remote_measurement, indices, remoteindices, generation)
    mREPORT_SUCCESS(success , indices, remoteindices, generation)
end

#= 
    R (or L) side of purify2to1[:X] and purify3to1[:Y]
    TODO: implement in CircuitZoo, once current pull req regarding CircuitZoo is merged
=#
function purify2to1(rega, regb; type::Symbol=:X)
    if type == :X
        apply!((regb, rega), CNOT)
        meas = project_traceout!(regb, σˣ)
        meas
    else
        apply!((rega, regb), CNOT)
        meas = project_traceout!(regb, σᶻ)
        meas
    end
end

function purify3to1(rega, regb, regc; type::Symbol=:Y)
    if type == :Y || type == :X
        apply!((rega, regb), CNOT)
        apply!((regc, regb), CNOT)

        meas1 = project_traceout!(regb, σᶻ)
        meas2 = project_traceout!(regc, σˣ)
        meas = [meas1, meas2]
        meas
    else
        apply!((rega, regb), XCZ)
        apply!((regc, regb), ZCY)

        meas1 = project_traceout!(regb, σˣ)
        meas2 = project_traceout!(regc, σʸ)
        meas = [meas1, meas2]
        meas
    end
end

# finding a free qubit in the local register
function findfreequbit(network, node)
    register = network[node]
    regsize = nsubsystems(register)
    findfirst(i->!isassigned(register, i) && !islocked(register[i]), 1:regsize)
end

# setting up the simulation
function simulation_setup(sizes, commtimes, protocol::FreeQubitTriggerProtocolSimulation)
    registers = Register[]
    for s in sizes
        push!(registers, Register(s))
    end

    graph = grid([length(sizes)]) # TODO: add as parameter so people can choose graph
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

# the trigger which triggers the entanglement start e.g. a free qubit is found
@resumable function freequbit_trigger(sim::Simulation, protocol::FreeQubitTriggerProtocolSimulation, network, node, remotenode, logfile=nothing)
    waittime = protocol.waittime
    busytime = protocol.busytime    
    channel = network[node=>remotenode, protocol.keywords[:simple_channel]]
    remote_channel = network[remotenode=>node, protocol.keywords[:simple_channel]]
    while true
        slog!(logfile, "$(now(sim)) :: $node > [SEARCHING] $node")

        i = findfreequbit(network, node)
        if isnothing(i)
            @yield timeout(sim, waittime)
            slog!(logfile, "$(now(sim)) :: $node > [NOTHING FOUND]")
            continue
        end

        @yield request(network[node][i])
        slog!(logfile, "[ENTANGLER TRIGGERED] $(now(sim)) :: $node > [trig] Locked $(node):$(i)")
        @yield timeout(sim, busytime)
        put!(channel, mFIND_QUBIT_TO_PAIR(i))
    end
end

@resumable function entangle(sim::Simulation, protocol::FreeQubitTriggerProtocolSimulation, network, node, remotenode, noisy_pair = noisy_pair_func(0.7)
    , logfile=nothing)
    waittime = protocol.waittime
    busytime = protocol.busytime
    channel = network[node=>remotenode, protocol.keywords[:simple_channel]]
    remote_channel = network[remotenode=>node, protocol.keywords[:simple_channel]]
    while true
        message = @yield take!(remote_channel)
        slog!(logfile, "$(now(sim)) :: $node > Replying to $message")
        
        @cases message begin
            mFIND_QUBIT_TO_PAIR(remote_i) => begin
                i = findfreequbit(network, node)
                if isnothing(i)
                    slog!(logfile, "$(now(sim)) :: $node > Nothing found at $node. Unlocking $remotenode:$remote_i")
                    put!(channel, mUNLOCK(remote_i))
                else
                    @yield request(network[node][i])
                    @yield timeout(sim, busytime)
                    network[node,:enttrackers][i] = (remotenode,remote_i)
                    put!(channel, mASSIGN_ORIGIN(i, remote_i))
                end
            end
            
            mASSIGN_ORIGIN(remote_i, i) => begin
                slog!(logfile, "$(now(sim)) :: $node > Pairing $node:$i, $remotenode:$remote_i")
                network[node,:enttrackers][i] = (remotenode,remote_i)
                put!(channel, mINITIALIZE_STATE(i, remote_i))
            end
            
            mINITIALIZE_STATE(remote_i, i) => begin
                initialize!((network[node][i], network[remotenode][remote_i]),noisy_pair; time=now(sim))
                slog!(logfile, "$(now(sim)) :: $node > Paired \t\t\t\t$node:$i, $remotenode:$remote_i")
                unlock(network[node][i])
                put!(channel, mUNLOCK(remote_i))
                @yield timeout(sim, busytime)
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
                slog!(logfile, "[*] $(now(sim)) :: $node > [*] UnLocked $node:$i \n")
                @yield timeout(sim, waittime)
            end

            mLOCK(i) => begin
                @yield request(network[node][i])
                slog!(logfile, "[*] $(now(sim)) :: $node > [*] Locked $node:$i \n")
                @yield timeout(sim, busytime)
            end
        end
    end
end

# listening on process channel
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
    purif_circuit_size = protocol.purifier_circuit_size
    while true
        message = @yield take!(remote_process_channel)
        @cases message begin
            mGENERATED_ENTANGLEMENT_REROUTED(remote_i, i, generation) => begin
                push!(indicesg[generation], i)
                push!(remoteindicesg[generation], remote_i)
                @yield request(network[node][i])
                @yield timeout(sim, busytime)
                put!(channel, mLOCK(remote_i))

                slog!(logfile, "$(now(sim)) :: $node > Locked $node:$i, $remotenode:$remote_i; Indices Queue: $(indicesg[generation]), $(remoteindicesg[generation]). Generation #$generation")

                if length(indicesg[generation]) == purif_circuit_size
                    slog!(logfile, "$(now(sim)) :: $node > PURIFICATION : Tupled pairs: $node:$(indicesg[generation]), $remotenode:$(remoteindicesg[generation]); Preparing for purification")
                    # begin purification of self
                    @yield timeout(sim, busytime)

                    slots = [network[node][x] for x in indicesg[generation]]
                    #slog!(logfile, slots)
                    local_measurement = protocol.purifier_circuit(slots...; type=(:X, :Z)[generation%2+1])
                    # send message to other node to apply purif side of circuit
                    put!(process_channel, mPURIFY(local_measurement, remoteindicesg[generation], indicesg[generation], generation))
                    indicesg[generation] = []
                    remoteindicesg[generation] = []
                end
            end

            mPURIFY(remote_measurement, indices, remoteindices, generation) => begin
                slots = [network[node][x] for x in indices]
                #slog!(logfile, slots)
                @yield timeout(sim, busytime)

                local_measurement = protocol.purifier_circuit(slots...; type=(:X, :Z)[generation%2+1])
                success = local_measurement == remote_measurement
                put!(process_channel, mREPORT_SUCCESS(success, remoteindices, indices, generation))
                if !success
                    slog!(logfile, "$(now(sim)) :: PURIFICATION FAILED > @ $node:$indices, $remotenode:$remoteindices")
                    traceout!(network[node][indices[1]])
                    network[node,:enttrackers][indices[1]] = nothing
                else
                    slog!(logfile, "$(now(sim)) :: PURIFICATION SUCCEDED > @ $node:$indices, $remotenode:$remoteindices\n")
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
                # OPTION: Here we have a choice. We can either leave it as such, or signal anouther entanglement generation to the simple channel
                if emitonpurifsuccess && success && generation+1 <= maxgeneration
                    @yield timeout(sim, busytime)
                    put!(channel, mGENERATED_ENTANGLEMENT(indices[1], remoteindices[1], generation+1)) # emit ready for purification and increase generation
                end
            end
        end
    end
end
