using QuantumSavory
using QuantumSavory.CircuitZoo
using QuantumSavory.ProtocolZoo
using ConcurrentSim
using QuantumOpticsBase
using ResumableFunctions
using NetworkLayout
using Random, StatsBase
using Graphs, GraphRecipes
using Graphs: grid

using DataFrames, StatsPlots
using CSV

using QuantumClifford: AbstractStabilizer, Stabilizer, graphstate, sHadamard, sSWAP, stabilizerview, canonicalize!, sCNOT, ghz

# using PyCall
# @pyimport pickle
# @pyimport networkx

using ArgParse
"""
    parse_commandline()
    Parse command line arguments using ArgParse.
    
    Returns:
        parsed_args (Dict): Dictionary containing parsed command line arguments.
"""
function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--size"
            help = "number of nodes in the graph state (or gridlenth if grid graph is used)"
            default = 50
            arg_type = Int
        "--graphtype", "-g"
            help = "type of the graph to be used, choose between 'path' and 'grid'"
            default = "path"
            arg_type = String
        "--file_index", "-f"
            help = "index of the file to be used"
            default = 1
            arg_type = Int
        "--protocol"
            help = "protocol to run, choose between 'sequential' and 'canonical'"
            default = "canonical"
            arg_type = String
        "--nsamples"
            help = "number of samples to be generated"
            arg_type = Int
            default = 1
        "--seed"
            help = "random seed"
            arg_type = Int
            default = 42
        "--output_path", "-o"
            help = "output path"
            arg_type = String
            default = "../output/"
    end

    return parse_args(s)
end
parsed_args = parse_commandline()


# """
#     get_graphdata_from_pickle(path)
#     Load the graph data from a pickle file and convert it to Julia format.
#     Args:
#         path (str): Path to the pickle file containing graph data.
#     Returns:
#         graphdata (Dict): Dictionary mapping tuples to tuples of Graph and Register.
#         operationdata (Dict): Dictionary mapping tuples to transition gate sets.
# """
# function get_graphdata_from_pickle(path)
#     graphdata = Dict{Tuple, Graph}()
#     projectors = Dict{Tuple, Any}()
#     operationdata = Dict{Tuple, Any}()
    
#     # Load the graph data in python from pickle file
#     graphdata_py = pickle.load(open(path, "r"))
#     n = nothing
#     for (key, value) in graphdata_py # value = [lc equivalent graph, transition gates
#         graph_py = value[1]
#         n = networkx.number_of_nodes(graph_py)

#         # Generate graph in Julia and apply the CZ gates to reference register
#         graph_jl = Graph()
#         add_vertices!(graph_jl, n)
#         for edge in value[1].edges
#             edgejl = map(x -> x + 1, Tuple(edge)) # +1 because Julia is 1-indexed
#             add_edge!(graph_jl, edgejl) 
#         end

#         # The core represents the key
#         key_jl = map(x -> x + 1, Tuple(key)) # +1 because Julia is 1-indexed
#         graphdata[key_jl] = graph_jl
#         projectors[key_jl] = projector(StabilizerState(Stabilizer(graph_jl))) # projectors for the graph states # TODO: using StabilizerState instead of Ket is not working!
#         operationdata[key_jl] = value[2][1,:] # Transition gate sets
#     end
#     return n, graphdata, operationdata, projectors
# end

"""
is_vertex_cover(g::AbstractGraph, S::Set{Int})::Bool
Return `true` iff every edge of `g` has at least one endpoint in `S`.
Runs in Θ(|E|) time.
"""
function is_vertex_cover(g::AbstractGraph, S::Set{Int})::Bool
    for e in edges(g)
        (src(e) ∈ S || dst(e) ∈ S) || return false
    end
    return true
end

"""
minimal_vertex_cover(g::AbstractGraph, S::Set{Int})::Set{Int}
Given a vertex cover S, return a *minimal* vertex cover contained in S
by deleting every redundant vertex. Returns a set with only 0 as an element if S is not a cover.
Runs in Θ(|V| + |E|) time.
"""
function minimal_vertex_cover(g::AbstractGraph, S::Set{Int})::Set{Int}
    is_vertex_cover(g, S) || return Set([0])  # return empty set if S is not a cover
    @debug g, S

    C = Set(S)                     # non-destructive copy
    for v in C
        neighs = neighbors(g, v)    # get neighbors of v and remove v if all neighbors are in C (then no edge can be uncovered by removing v)
        issubset(neighs, C) && delete!(C, v)  # remove neighbors from C
    end
    return C
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

@resumable function Logger(sim::Environment, net::RegisterNet, logging::DataFrame, graph::Graph)
    # Wait until all clients have been corrected
    corrected = 0
    while corrected < n
        @yield wait(messagebuffer(net[1]))
        if !isnothing(querydelete!(messagebuffer(net[1]), :corrected))
            corrected += 1
        end
    end

    # Now we can calculate the fidelity and log the outcome
    @yield reduce(&, [lock(net[idx+1][1]) for idx in 1:n])
    fidelity = real(observable([net[idx+1][1] for idx in 1:n], prjtr; time=now(sim)))
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

"""
    Central switch routine that waits for all link-level EPR pairs, selects
    a suitable vertex cover from `vcs`, distributes the corresponding graph
    state across the clients and initiates the CZ-and-measurement phase.

    Args:
        sim: Simulation time-tracker.
        net: Quantum network with the switch at node 1 and `n` clients.
        n: Number of client nodes.
        vcs: A collection of vertex covers; the first cover contained in the
            current set of active qubits is chosen and its index broadcast to
            the clients.

    Returns:
        Nothing. The function spawns `apply_cz_and_measure` processes for every
        client once all EPR pairs are available.
"""
@resumable function GraphCanonicalProt(sim::Environment, net::RegisterNet, n::Int, vcs::Vector{Tuple})

    graph = Graph() # general graph object, to be later replaced by chosen graph
    counter_clients = 0 # counts clients that are entangled
    active = Set{Int}() # qubits that have an EPR pair 
    cover_idx = nothing # index in vcs (fixed once)

    while counter_clients < n

        @yield onchange_tag(net[1])
        while true # until the query returns nothing (multiple clients can be successful in parallel)
            counterpart = querydelete!(net[1], EntanglementCounterpart, ❓, ❓)
            if !isnothing(counterpart)
                slot, _, _ = counterpart
                push!(active, slot.idx)
                counter_clients += 1
            else
                break
            end
        end
        if isnothing(cover_idx) # using the same seed, generates the same graph as in the sequential case, see GRAPHsequentialgeneral.jl
            cover_idx = findfirst(vcs) do cover # take first vertex cover that is present
                cover ⊆ active
            end
        end
        isnothing(cover_idx) && continue 
        graph = deepcopy(graphdata[vcs[cover_idx]]) # graph to be generated
        put!(channel(net, 1=>2), Tag(:cover, cover_idx))
    end

    # All clients have established their link-level entanglement
    for idx in 1:n
        @yield @process apply_cz_and_measure(sim, net, idx, graph) # apply CZ gates, measure and send the result to the client
    end

end

@resumable function GraphCanonicalProt(sim::Environment, net::RegisterNet, n::Int, graph::Graph)

    counter_clients = 0 # counts clients that are entangled
    active = Set{Int}() # qubits that have an EPR pair 

    while counter_clients < n

        @yield onchange_tag(net[1])
        while true # until the query returns nothing (multiple clients can be successful in parallel)
            counterpart = querydelete!(net[1], EntanglementCounterpart, ❓, ❓)
            if !isnothing(counterpart)
                slot, _, _ = counterpart
                push!(active, slot.idx)
                counter_clients += 1
            else
                break
            end
        end
    end

    # All clients have established their link-level entanglement
    graph = deepcopy(graph) # graph to be generated
    for idx in 1:n
        @yield @process apply_cz_and_measure(sim, net, idx, graph) # apply CZ gates, measure and send the result to the client
    end

end

"""
    Central switch routine that waits for link-level EPR pairs, selects
    a suitable vertex cover from `vcs`, distributes the corresponding graph
    state across the clients and initiates the CZ-and-measurement phase sequentially.

    Args:
        sim: Simulation time-tracker.
        net: Quantum network with the switch at node 1 and `n` clients.
        n: Number of client nodes.
        vcs: A collection of vertex covers; the first cover contained in the
            current set of active qubits is chosen and its index broadcast to
            the clients.

    Returns:
        Nothing. The function spawns `apply_cz_and_measure` processes for every
        client once all EPR pairs are available.
"""
@resumable function GraphSequentialProt(sim::Environment, net::RegisterNet, n::Int, vcs::Vector{Tuple})
    println("GraphSequentialProt called with vcs.")

    graph = Graph() # general graph object, to be later replaced by chosen graph
    counter_clients = 0 # counts clients that are entangled
    active = Set{Int}() # qubits that have an EPR pair 
    cover_idx = nothing # index in vcs (fixed once)

    # Wait until core is present
    while isnothing(cover_idx)
        @yield onchange_tag(net[1])
        while true # until the query returns nothing (multiple clients can be successful in parallel)
            counterpart = querydelete!(net[1], EntanglementCounterpart, ❓, ❓)
            if !isnothing(counterpart)
                slot, _, _ = counterpart
                push!(active, slot.idx)
                counter_clients += 1
            else
                break
            end
        end
        if isnothing(cover_idx)
            @debug "Active clients: ", active
            cover_idx = findfirst(vcs) do cover # check if a core is present
                cover ⊆ active
            end 
        end
        isnothing(cover_idx) && continue # no core found yet so skip and redo loop
        graph = deepcopy(graphdata[vcs[cover_idx]]) # otherwise select graph to be generated

        @debug "Core found: ", vcs[cover_idx]
        put!(channel(net, 1=>2), Tag(:cover, cover_idx)) # send the index of the vertex cover to the Logger

        active_non_cover_qubits = setdiff(active, vcs[cover_idx]) # active qubits that are not in the vertex cover
        @debug "Non-cover qubits: ", active_non_cover_qubits 

        # Measure out all qubits that arrived before vertex cover was present
        for idx in active_non_cover_qubits
            @yield @process apply_cz_and_measure(sim, net, idx, graph) # apply CZ gates, measure and send the result to the client
        end
    end

    # Now we wait for the rest of the qubits to arrive 
    while counter_clients <= n
        counter_clients == n && break # all clients already measured out so skip this loop
        currently_active = Set{Int}() # qubits that have an EPR pair
        @yield onchange_tag(net[1])
        while true # until the query returns nothing
            counterpart = querydelete!(net[1], EntanglementCounterpart, ❓, ❓)
            if !isnothing(counterpart)
                slot, _, _ = counterpart
                push!(currently_active, slot.idx)
                counter_clients += 1
            else
                break
            end
        end

        current_non_cover_qubits = setdiff(currently_active, vcs[cover_idx]) # currently present qubits that are not in the vertex cover
        @debug "Non-cover qubits that arrived after vertex cover qubits: ", current_non_cover_qubits 
        for idx in current_non_cover_qubits
            @yield @process apply_cz_and_measure(sim, net, idx, graph) # apply CZ gates, measure and send the result to the client
        end

    end

    # Finally only the cover qubits are left to measure out
    for idx in vcs[cover_idx]
        @yield @process apply_cz_and_measure(sim, net, idx, graph) # apply CZ gates, measure and send the result to the client
    end
end

@resumable function GraphSequentialProt(sim::Environment, net::RegisterNet, n::Int, graph::Graph)

    counter_clients = 0 # counts clients that are entangled
    active = Set{Int}() # qubits that have an EPR pair 
    cover = nothing # minimal vertex cover (fixed once)

    # Wait until core is present
    while isnothing(cover)
        @yield onchange_tag(net[1])
        while true # until the query returns nothing (multiple clients can be successful in parallel)
            counterpart = querydelete!(net[1], EntanglementCounterpart, ❓, ❓)
            if !isnothing(counterpart)
                slot, _, _ = counterpart
                push!(active, slot.idx)
                counter_clients += 1
            else
                break
            end
        end
        @debug "Active clients: ", active
        if isnothing(cover)
            # check if a core is present
            mvc = minimal_vertex_cover(graph, active)
            if mvc != Set([0]) # if the set is not empty, we have a cover
                cover = mvc
            end
        end
        isnothing(cover) && continue # no core found yet so skip and redo loop
        graph = deepcopy(graph) # otherwise select graph to be generated

        @debug "Core found: ", cover

        active_non_cover_qubits = setdiff(active, cover) # active qubits that are not in the vertex cover
        @debug "Non-cover qubits: ", active_non_cover_qubits 

        # Measure out all qubits that arrived before vertex cover was present
        for idx in active_non_cover_qubits
            @yield @process apply_cz_and_measure(sim, net, idx, graph) # apply CZ gates, measure and send the result to the client
        end
    end

    # Now we wait for the rest of the qubits to arrive 
    while counter_clients <= n
        counter_clients == n && break # all clients already measured out so skip this loop
        currently_active = Set{Int}() # qubits that have an EPR pair
        @yield onchange_tag(net[1])
        while true # until the query returns nothing
            counterpart = querydelete!(net[1], EntanglementCounterpart, ❓, ❓)
            if !isnothing(counterpart)
                slot, _, _ = counterpart
                push!(currently_active, slot.idx)
                counter_clients += 1
            else
                break
            end
        end

        current_non_cover_qubits = setdiff(currently_active, cover) # currently present qubits that are not in the vertex cover
        @debug "Non-cover qubits that arrived after vertex cover qubits: ", current_non_cover_qubits 
        for idx in current_non_cover_qubits
            @yield @process apply_cz_and_measure(sim, net, idx, graph) # apply CZ gates, measure and send the result to the client
        end

    end

    # Finally only the cover qubits are left to measure out
    for idx in cover
        @yield @process apply_cz_and_measure(sim, net, idx, graph) # apply CZ gates, measure and send the result to the client
    end
end

"""
    prepare_sim(protocol::Function, n::Int, states_representation::AbstractRepresentation, noise_model::Union{AbstractBackground, Nothing}, link_success_prob::Float64, logging::DataFrame, graphdata::Any)

    Prepare the simulation environment for the given protocol.

    Args:
        protocol (Function): The protocol function to be executed.
        n (Int): Number of clients.
        states_representation (AbstractRepresentation): Representation of the quantum states.
        noise_model (Union{AbstractBackground, Nothing}): Noise model to be used.
        link_success_prob (Float64): Probability of successful link establishment.
        logging (DataFrame): DataFrame to log simulation results.
        graphdata (Any): Graph data for the simulation.

    Returns:
        sim: The simulation object.
"""
function prepare_sim(protocol::Function, n::Int, states_representation::AbstractRepresentation, noise_model::Union{AbstractBackground, Nothing}, link_success_prob::Float64, logging::DataFrame, graphdata::Any)

    graph = star_graph(n+1)
    
    switch = Register([Qubit() for _ in 1:n], [states_representation for _ in 1:n], [noise_model for _ in 1:n]) # storage qubits at the switch, where n qubits are not affected by noise
    clients = [Register([Qubit()], [states_representation], [noise_model]) for _ in 1:n] # client qubits
    net = RegisterNet(graph, [switch, clients...])
    sim = get_time_tracker(net)

    # Start entanglement generation for each client
    for i in 1:n
        @process entangle(sim, net, 1, i, link_success_prob)
    end

    # Each client applies a correction upon receiving a message
    for i in 1:n
        @process Corrector(sim, net, i)
    end

    # Start the piecemaker protocol on the switch
    @process protocol(sim, net, n, graphdata)

    @process Logger(sim, net, logging, graphdata)

    return sim
end