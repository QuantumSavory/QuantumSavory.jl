using QuantumSavory
using QuantumSavory.CircuitZoo
using QuantumSavory.ProtocolZoo
using ConcurrentSim
using QuantumOpticsBase
using ResumableFunctions
using NetworkLayout
using Random, StatsBase
using Graphs, GraphRecipes

using DataFrames, StatsPlots
using CSV

using QuantumClifford: AbstractStabilizer, Stabilizer, graphstate, sHadamard, sSWAP, stabilizerview, canonicalize!, sCNOT, ghz

using PyCall
@pyimport pickle
@pyimport networkx


"""
    get_graphdata_from_pickle(path)
    Load the graph data from a pickle file and convert it to Julia format.
    Args:
        path (str): Path to the pickle file containing graph data.
    Returns:
        graphdata (Dict): Dictionary mapping tuples to tuples of Graph and Register.
        operationdata (Dict): Dictionary mapping tuples to transition gate sets.
"""
function get_graphdata_from_pickle(path)
    graphdata = Dict{Tuple, Graph}()
    projectors = Dict{Tuple, Any}()
    operationdata = Dict{Tuple, Any}()
    
    # Load the graph data in python from pickle file
    graphdata_py = pickle.load(open(path, "r"))
    n = nothing
    for (key, value) in graphdata_py # value = [lc equivalent graph, transition gates
        graph_py = value[1]
        n = networkx.number_of_nodes(graph_py)

        # Generate graph in Julia and apply the CZ gates to reference register
        graph_jl = Graph()
        add_vertices!(graph_jl, n)
        for edge in value[1].edges
            edgejl = map(x -> x + 1, Tuple(edge)) # +1 because Julia is 1-indexed
            add_edge!(graph_jl, edgejl) 
        end

        # The core represents the key
        key_jl = map(x -> x + 1, Tuple(key)) # +1 because Julia is 1-indexed
        graphdata[key_jl] = graph_jl
        projectors[key_jl] = projector(Ket(Stabilizer(graph_jl))) # projectors for the graph states # TODO: using StabilizerState instead of Ket is not working!
        operationdata[key_jl] = value[2][1,:] # Transition gate sets
    end
    return n, graphdata, operationdata, projectors
end

"""
    Generates an EPR pair between the storage qubit at the switch node and the
    client at position `clientidx` in the network.

    Args:
        sim: The global simulation time-tracker.
        net: The `RegisterNet` representing the quantum network.
        switchidx: Index of the switch node inside `net` (typically `1`).
        clientidx: Index of the client node to entangle with the switch.
        link_success_prob: Success probability of a single entanglement attempt.

    Returns:
        Nothing. The function yields control back to the scheduler while the
        `EntanglerProt` process runs and eventually writes an
        `EntanglementCounterpart` tag into the switch message buffer.
"""
@resumable function entangle(sim::Environment, net::RegisterNet, switchidx::Int, clientidx::Int, link_success_prob::Float64)
    entangler = EntanglerProt(
        sim=sim, net=net, nodeA=switchidx, slotA=clientidx, nodeB=clientidx+1, slotB=1,
        success_prob=link_success_prob, rounds=1, attempts=-1, attempt_time=1.0,
        )
    @yield @process entangler()
end

"""
    Subprotocol running on a client `idx`. Listens for the X basis measurement result sent by the switch and apply the
    required Pauli Z correction to the client qubit at node `idx+1`.

    Args:
        sim: The global simulation time-tracker.
        net: The `RegisterNet` containing the switch (node 1) and all clients.
        idx: Index of the client in the caller's numbering (the
            corresponding node in `net` is `idx + 1`).

    Returns:
        Nothing. When the correction has been applied, the function sends a
        `Tag(:corrected)` message to the switch and terminates.
"""
@resumable function Corrector(sim::Environment, net::RegisterNet, idx::Int)
    messagebuffer = messagebuffer(net[idx+1])
    while true
        @yield wait(messagebuffer)
        msg = querydelete!(messagebuffer, :measx, ❓)
        !isnothing(msg) && begin 
            _, xmeas_outcome =  msg.tag
            @yield lock(net[idx+1][1])
            xmeas_outcome == 2 && apply!(net[idx+1][1], Z, time=now(sim))
            put!(channel(net, idx+1=>1), Tag(:corrected))
            unlock(net[idx+1][1])
            break
        end
    end
end

"""
    Apply controlled Z (CZ) gates between the qubit of client `idx` and all its
    neighbors in the target graph, then measure that qubit in the X basis and
    forward the outcome to the corresponding client process.

    Args:
        sim: The global simulation time-tracker.
        net: The `RegisterNet` with the switch at node 1 and clients at
            node `2 ... n+1`.
        idx: Index of the client (starting at 1).
        graph: `Graph` object whose edges specify which CZ gates must be
            applied.

    Returns:
        Nothing. Measurement outcomes are sent via
        `Tag(:measx, xmeas_outcome)` to the client.
"""
@resumable function apply_cz_and_measure(sim::Environment, net::RegisterNet, idx::Int, graph::Graph)
    neighs = neighbors(graph, idx) # get all neighbors of client #idx
    @debug "neighbors of $(idx): ", neighs
    while !isempty(neighs)
        nb = neighs[1]
        @yield lock(net[1][idx]) & lock(net[1][nb])
        apply!((net[1][idx], net[1][nb]), ZCZ; time=now(sim))
        unlock(net[1][idx])
        unlock(net[1][nb])
        @debug "apply CZ to $(idx) and $(nb)"
        rem_edge!(graph, idx, nb)
    end
    @yield lock(net[1][idx])
    xmeas = project_traceout!(net[1][idx], σˣ)
    unlock(net[1][idx])
    put!(channel(net, 1=>idx+1), Tag(:measx, signed(xmeas))) # send the measurement outcome to the client
end

"""
    Wait until all client qubits have been corrected, then evaluate the global
    state fidelity with respect to the target graph state stored in `const` `projectors` 
    and append the result to the provided `logging` dataframe.

    Args:
        sim: Simulation time-tracker.
        net: The `RegisterNet` with the switch at node 1.
        logging: `DataFrame` that collects tuples `(time, fidelity)`.
        vcs: Vector of vertex-cover sets; the switch announces the index of the
            chosen cover via a `Tag(:cover, cover_idx)` message.

    Returns:
        Nothing. A new row is pushed to `logging` once fidelity has been
        computed.

    Note:
        The global constant `n` must equal the number of clients; it is used to
        decide when all corrections are complete.
"""
@resumable function Logger(sim::Environment, net::RegisterNet, logging::DataFrame, vcs::Vector{Tuple})
    # Wait until all clients have been corrected
    corrected = 0
    while corrected < n
        @yield wait(messagebuffer(net[1]))
        if !isnothing(querydelete!(messagebuffer(net[1]), :corrected))
            corrected += 1
        end
    end
    msg = querydelete!(messagebuffer(net[2]), :cover, ❓)
    _, cover_idx = msg.tag

    # Now we can calculate the fidelity and log the outcome
    @yield reduce(&, [lock(net[idx+1][1]) for idx in 1:n])
    obs = projectors[vcs[cover_idx]]
    fidelity = real(observable([net[idx+1][1] for idx in 1:n], obs; time=now(sim)))
    @debug "Fidelity: ", fidelity
    foreach(q -> (traceout!(q); unlock(q)), [net[idx+1][1] for idx in 1:n])

    # Log outcome
    push!(
        logging,
        (
            now(sim), fidelity
        )
    )
end