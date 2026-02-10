using QuantumSavory
using QuantumSavory.ProtocolZoo
using Graphs
using ConcurrentSim
using ResumableFunctions
using NetworkLayout
using DataFrames
using Random
using QuantumClifford: ghz

const ghzs = [ghz(n) for n in 1:35] # make const in order to not build new every time

"""
    push_to_logging!(logging::Vector, t::Float64, fidelity::Float64)

Append a time-fidelity data point to the logging vector.

# Arguments
- `logging::Vector`: Vector of `Point2f` storing (time, fidelity) pairs
- `t::Float64`: Simulation time at which the measurement was taken
- `fidelity::Float64`: Measured fidelity to the target GHZ state
"""
function push_to_logging!(logging::Vector, t::Float64, fidelity::Float64)
    push!(logging, (t, fidelity))
end

"""
    fusion(piecemaker_slot::RegRef, client_slot::RegRef)

Perform a fusion operation between a piecemaker qubit and a client qubit.

Applies a CNOT gate with the piecemaker qubit as control and the client qubit
as target, then measures the client qubit in the Z basis and traces it out.

# Arguments
- `piecemaker_slot::Int`: Register slot index containing the piecemaker qubit
- `client_slot::Int`: Register slot index containing the client qubit to be fused

# Returns
- Measurement outcome (1 or 2) from projecting the client qubit onto the Z basis
"""
function fusion(piecemaker_slot::RegRef, client_slot::RegRef)
    apply!((piecemaker_slot, client_slot), CNOT)
    res = project_traceout!(client_slot, σᶻ)
    return res
end

"""
    EntanglementCorrector(sim, net::RegisterNet, node::Int)

Resumable function that waits for X correction messages and applies them.

This protocol monitors a client node for `:updateX` tags sent by the switch
after fusion operations. When received, it applies an X gate if needed (when
the measurement outcome is 2) to correct the client's qubit state.

# Arguments
- `sim`: ConcurrentSim simulation environment
- `net::RegisterNet`: Network containing all nodes
- `node::Int`: Index of the client node to monitor and correct
"""
@resumable function EntanglementCorrector(sim, net::RegisterNet, node::Int)
    while true
        @yield onchange_tag(net[node][1])
        msg = querydelete!(net[node][1], :updateX, ❓)
        if !isnothing(msg)
            value = msg[3][2]
            @yield lock(net[node][1])
            @debug "X received at node $(node), with value $(value)"
            value == 2 && apply!(net[node][1], X)
            unlock(net[node][1])
            break
        end
    end
end

"""
    Logger(sim, net::RegisterNet, node::Int, n::Int, start_of_round)

Resumable function that applies Z corrections and measures final GHZ fidelity.

Waits for a `:updateZ` tag from the switch (sent after measuring the piecemaker
qubit in the X basis), applies the necessary Z correction if the measurement
outcome is 2, then measures the fidelity of the resulting n-qubit state to the
target GHZ state and logs it. Pushes a (time, fidelity) data point to the global
`logging` vector via `push_to_logging!`

# Arguments
- `sim`: ConcurrentSim simulation environment
- `net::RegisterNet`: Network containing all nodes
- `node::Int`: Index of the client node receiving the Z correction
- `n::Int`: Number of clients in the GHZ state
- `start_of_round`: Simulation time when the current round started
"""
@resumable function Logger(sim, net::RegisterNet, node::Int, n::Int, start_of_round)
    msg = querydelete!(net[node], :updateZ, ❓)
    if isnothing(msg)
        error("No message received at node $(node) with tag :updateZ.")
    else
        value = msg[3][2]
        @debug "Z received at node $(node), with value $(value)"
        @yield lock(net[node][1])
        value == 2 && apply!(net[node][1], Z)
        unlock(net[node][1])

        # Measure the fidelity to the GHZ state
        @yield reduce(&, [lock(q) for q in net[2]])
        obs_proj = SProjector(StabilizerState(ghzs[n])) # GHZ state projector to measure
        fidelity = real(observable([net[i+1][1] for i in 1:n], obs_proj; time = now(sim)))
        t = now(sim) - start_of_round
        @debug "Fidelity: $(fidelity)"
        push_to_logging!(logging, t, fidelity)
    end
end

"""
    clear_up_qubits!(net::RegisterNet, n::Int)

Clean up all qubits at the switch and client nodes after a round.

Traces out and unlocks all storage qubits at the switch (node 1) and the
first qubit at each of the n client nodes, preparing the network for the
next round or simulation end.

# Arguments
- `net::RegisterNet`: Network containing all nodes
- `n::Int`: Number of client nodes
"""
function clear_up_qubits!(net::RegisterNet, n::Int)
    # cleanup qubits
    foreach(q -> (traceout!(q); unlock(q)), net[1])
    foreach(q -> (traceout!(q); unlock(q)), [net[1 + i][1] for i in 1:n])
end

"""
    PiecemakerProt(sim, n::Int, net::RegisterNet, link_success_prob::Float64, rounds::Int)

Main resumable protocol for the piecemaker quantum switching scheme.

Orchestrates the generation of n-qubit GHZ states across client nodes using
a central switch node. Each round:
1. Establishes entanglement between the switch and each client in parallel
2. Fuses successful client qubits with a piecemaker qubit at the switch via CNOT
3. Measures the piecemaker qubit in the X basis to project clients into a GHZ state
4. Communicates measurement outcomes for local corrections
5. Logs the fidelity to the target GHZ state and cleans up resources

# Arguments
- `sim`: ConcurrentSim simulation environment
- `n::Int`: Number of client nodes (GHZ state size)
- `net::RegisterNet`: Network with star topology (switch at center, clients at leaves)
- `link_success_prob::Float64`: Probability of successful entanglement per attempt
- `rounds::Int`: Number of GHZ generation rounds to execute

# Protocol Overview
The piecemaker protocol generates multipartite entanglement by:
- Creating Bell pairs between switch and each client using `EntanglerProt`
- Fusing these pairs at the switch using a |+⟩ "piecemaker" qubit (slot n+1)
- Measuring the piecemaker in the X basis to project clients into GHZ
- Communicating measurement outcomes via tags for local X and Z corrections
"""
@resumable function PiecemakerProt(sim, n::Int, net::RegisterNet, link_success_prob::Float64, rounds::Int)
    while rounds != 0
        @debug "round $(rounds)"
        start = now(sim)

        for i in 1:n
            entangler = EntanglerProt(
                sim = sim, net = net, nodeA = 1, chooseslotA = i, nodeB = 1 + i, chooseslotB = 1,
                success_prob = link_success_prob, rounds = 1, attempts = -1, attempt_time = 1.0,
            )
            @process entangler()
        end

        for i in 1:n
            @process EntanglementCorrector(sim, net, 1 + i)
        end

        while true
            # Look for EntanglementCounterpart changed on switch
            counter = 0
            while counter < n # until all clients are entangled
                @yield onchange_tag(net[1])
                if counter == 0 
                    # Initialize "piecemaker" qubit in |+> state when first qubit arrived
                    initialize!(net[1][n+1], X1, time = now(sim))
                end

                while true
                    counterpart = querydelete!(net[1], EntanglementCounterpart, ❓, ❓)
                    if !isnothing(counterpart)
                        slot, _, _ = counterpart

                        # fuse the qubit with the piecemaker qubit
                        @yield lock(net[1][n+1]) & lock(net[1][slot.idx])
                        res = fusion(net[1][n+1], net[1][slot.idx])
                        unlock(net[1][n+1]); unlock(net[1][slot.idx])
                        tag!(net[1 + slot.idx][1], Tag(:updateX, Int(res))) # communicate change to client node
                        counter += 1
                        @debug "Fused client $(slot.idx) with piecemaker qubit"
                    else
                        break
                    end
                end
            end

            @debug "All clients entangled, measuring piecemaker | time: $(now(sim)-start)"
            @yield lock(net[1][n+1])
            res = project_traceout!(net[1][n+1], σˣ)
            unlock(net[1][n+1])
            tag!(net[2][1], Tag(:updateZ, Int(res))) # communicate change to client node
            break
        end

        @yield @process Logger(sim, net, 2, n, start)

        # cleanup qubits
        clear_up_qubits!(net, n)
        rounds -= 1
        @debug "Round $(rounds) finished"
    end
end

function prepare_sim(n::Int, states_representation::AbstractRepresentation, noise_model::Union{AbstractBackground, Nothing}, 
    link_success_prob::Float64, seed::Int, rounds::Int)

    # Set a random seed
    Random.seed!(seed)

    switch = Register([Qubit() for _ in 1:(n+1)], [states_representation for _ in 1:(n+1)], [noise_model for _ in 1:(n+1)]) # storage qubits at the switch, first qubit is the "piecemaker" qubit
    clients = [Register([Qubit()], [states_representation], [noise_model]) for _ in 1:n] # client qubits
    
    graph = star_graph(n+1)
    net = RegisterNet(graph, [switch, clients...])
    sim = get_time_tracker(net)

    # Start the piecemaker protocol
    @process PiecemakerProt(sim, n, net, link_success_prob, rounds)
    return sim
end