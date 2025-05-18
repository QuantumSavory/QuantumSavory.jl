include("GRAPHutils.jl") # to import graphdata from pickle files

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
    @process GraphSequentialProt(sim, net, n, vcs)

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
CSV.write("examples/graphstateswitch/output/factory/qs_graph6_wheelsequentialgeneral_sweep.csv", df_all_runs)