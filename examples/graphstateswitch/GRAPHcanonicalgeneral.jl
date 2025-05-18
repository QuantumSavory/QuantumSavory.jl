include("GRAPHutils.jl") # to import graphdata from pickle files

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

function prepare_sim(n::Int, states_representation::AbstractRepresentation, noise_model::Union{AbstractBackground, Nothing}, link_success_prob::Float64, logging::DataFrame, graphdata::Any)

    graph = star_graph(n+1)
    
    switch = Register([Qubit() for _ in 1:n], [states_representation for _ in 1:n], [noise_model for _ in 1:n]) # storage qubits at the switch, where n qubits are not affected by noise
    clients = [Register([Qubit()], [states_representation], [noise_model]) for _ in 1:n] # client qubits
    net = RegisterNet(graph, [switch, clients...])
    sim = get_time_tracker(net)

    vcs = collect(keys(graphdata)) # vertex covers TODO: can this be prettier?

    # Start entanglement generation for each client
    for i in 1:n
        @process entangle(sim, net, 1, i, link_success_prob)
    end

    # Each client applies a correction upon receiving a message
    for i in 1:n
        @process Corrector(sim, net, i)
    end

    # Start the piecemaker protocol on the switch
    @process GraphCanonicalProt(sim, net, n, vcs)

    @process Logger(sim, net, logging, vcs)

    return sim
end


nr = 4
const n, graphdata, _, projectors = get_graphdata_from_pickle("examples/graphstateswitch/input/6_wheel_graph.pickle")
states_representation = CliffordRepr() #QuantumOpticsRepr() #
number_of_samples = 10000
seed = 42

# Set a random seed
Random.seed!(seed)

df_all_runs = DataFrame()
for prob in range(0.1, stop=1, length=10) #cumsum([9/i for i in exp10.(range(1, 10, 10))])#
    for mem_depolar_prob in exp10.(range(-3, stop=0, length=10)) #[0.001, 0.0001, 0.00001]#

        logging = DataFrame(
            distribution_times  = Float64[],
            fidelities    = Float64[]
        )
        decoherence_rate = - log(1 - mem_depolar_prob)
        noise_model = Depolarization(1/decoherence_rate)

        times = Float64[]
        for i in 1:number_of_samples
            sim = prepare_sim(n, states_representation, noise_model, prob, logging, graphdata)
        
            timed = @elapsed run(sim) # time and run the simulation
            push!(times, timed)
            @info "Sample $(i) finished", timed
        end

        logging[!, :elapsed_time] .= times
        logging[!, :number_of_samples] .= number_of_samples
        logging[!, :link_success_prob] .= prob
        logging[!, :mem_depolar_prob] .= mem_depolar_prob
        logging[!, :num_remote_nodes] .= n
        logging[!, :seed] .= seed
        append!(df_all_runs, logging)
        @debug "Mem depolar probability: $(mem_depolar_prob) | Link probability: $(prob)| Time: $(sum(times))"
    end
end
#@info df_all_runs
CSV.write("examples/graphstateswitch/output/factory/qs_graph6_wheelcanonicalgeneral_sweep.csv", df_all_runs)