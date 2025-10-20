using QuantumSavory
using QuantumSavory.ProtocolZoo
using Graphs
using ConcurrentSim
using ResumableFunctions
using NetworkLayout
using DataFrames
using Random
using QuantumClifford: ghz

const ghzs = [ghz(n) for n in 1:7] # make const in order to not build new every time

function push_to_logging!(logging::Vector, t::Float64, fidelity::Float64)
    push!(logging, Point2f(t, fidelity))
end

function fusion(piecemaker_slot, client_slot)
    apply!((piecemaker_slot, client_slot), CNOT)
    res = project_traceout!(client_slot, σᶻ)
    return res
end

@resumable function EntanglementCorrector(sim, net, node)
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

@resumable function Logger(sim, net, node, n, start_of_round)
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

function clear_up_qubits!(net, n)
    # cleanup qubits
    foreach(q -> (traceout!(q); unlock(q)), net[1])
    foreach(q -> (traceout!(q); unlock(q)), [net[1 + i][1] for i in 1:n])
end

@resumable function PiecemakerProt(sim, n, net, link_success_prob, rounds)
    while rounds != 0
        @debug "round $(rounds)"
        start = now(sim)

        for i in 1:n
            entangler = EntanglerProt(
                sim = sim, net = net, nodeA = 1, chooseA = i, nodeB = 1 + i, chooseB = 1,
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
                        tag!(net[1 + slot.idx][1], Tag(:updateX, res)) # communicate change to client node
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
            tag!(net[2][1], Tag(:updateZ, res)) # communicate change to client node
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