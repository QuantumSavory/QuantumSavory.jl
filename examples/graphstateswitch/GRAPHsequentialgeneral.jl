
include("utils.jl")

@resumable function GraphSequentialProt(sim, n, net, link_success_prob, logging, rounds, graphdata)

    while rounds != 0
        start = now(sim)

        # Start entanglement generation for each client
        for i in 1:n
            @process entangle(sim, net, i, link_success_prob)
        end

        vcs = collect(keys(graphdata)) # vertex covers TODO: can this be prettier?
        graph = Graph() # general graph object, to be later replaced by chosen state

        # vcs  = [(1,3), (2,4), (2,3)]
        # graph = Graph()
        # add_vertices!(graph, n)
        # for i in 1:n-1
        #     add_edge!(graph, (i, i+1))
        # end
        # refgraph = copy(graph)

        cover_idx = nothing # index in vcs (fixed once)
        counter_clients = 0 # counts clients that are entangled
        active = Set{Int}() # qubits that have an EPR pair 

        # Wait until core is present
        while isnothing(cover_idx)
            @yield onchange_tag(net[1])
            while true # until the query returns nothing
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
            graph = deepcopy(graphdata[vcs[cover_idx]]) # graph to be generated

            @debug "Core found: ", vcs[cover_idx]
            active_non_cover_qubits = setdiff(active, vcs[cover_idx]) # active qubits that are not in the vertex cover
            @debug "Non-cover qubits: ", active_non_cover_qubits 

            # Measure out all qubits that arrived before vertex cover was present
            for idx in active_non_cover_qubits
                neighs = neighbors(graph, idx)
                while !isempty(neighs)
                    nb = neighs[1]
                    @assert nb in vcs[cover_idx] "Neighbor $(nb) not in active qubits" # all neighbors should be vertex cover qubits
                    @yield lock(net[1][idx]) & lock(net[1][nb])
                    apply!((net[1][idx], net[1][nb]), ZCZ; time=now(sim))
                    unlock(net[1][idx])
                    unlock(net[1][nb])
                    @debug "apply CZ to $(idx) and $(nb)"
                    rem_edge!(graph, idx, nb)
                end
                @yield lock(net[1][idx]) & lock(net[2][idx])
                # measure out the qubit and apply correction on client side
                ( project_traceout!(net[1][idx], σˣ) == 2 ) && apply!(net[2][idx], Z)
                unlock(net[1][idx])
                unlock(net[2][idx])
            end
        end

        # Now we wait for the rest of the qubits to arrive (if there are any)
        while counter_clients <= n
            counter_clients == n && break # all qubits present so skip this loop
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
            @debug "Non-cover qubits in the second section of waiting: ", current_non_cover_qubits 
            for idx in current_non_cover_qubits
                neighs = neighbors(graph, idx)
                while !isempty(neighs)
                    nb = neighs[1]
                    @assert nb in vcs[cover_idx] "Neighbor $(nb) not in active qubits" # all neighbors should be vertex cover qubits
                    @yield lock(net[1][idx]) & lock(net[1][nb])
                    apply!((net[1][idx], net[1][nb]), ZCZ; time=now(sim))
                    unlock(net[1][idx])
                    unlock(net[1][nb])
                    rem_edge!(graph, idx, nb)
                end
                @yield lock(net[1][idx]) & lock(net[2][idx])
                # measure out the qubit and apply correction on client side
                ( project_traceout!(net[1][idx], σˣ) == 2 ) && apply!(net[2][idx], Z)
                unlock(net[1][idx])
                unlock(net[2][idx])
            end

        end

        # Finally only the cover qubits are left to measure out
        for idx in vcs[cover_idx]
            neighs = neighbors(graph, idx)
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
            @yield lock(net[1][idx]) & lock(net[2][idx])
            # measure out the qubit and apply correction on client side
            ( project_traceout!(net[1][idx], σˣ) == 2 ) && apply!(net[2][idx], Z)
            unlock(net[1][idx])
            unlock(net[2][idx])
        end
        @yield reduce(&, [lock(q) for q in net[2]])

        # Calculate fidelity
        @debug collect(edges(graph))
        obs = projectors[vcs[cover_idx]]
        fidelity = real(observable([net[2][i] for i in 1:n], obs; time=now(sim)))
        foreach(q -> (traceout!(q); unlock(q)), net[2])

        # Log outcome
        push!(
            logging,
            (
                now(sim)-start, fidelity, vcs[cover_idx], [(src(e), dst(e)) for e in  edges(graph)]
            )
        )
        rounds -= 1
        @debug "Round $(rounds) finished"
    end

end

function prepare_sim(n::Int, states_representation::AbstractRepresentation, noise_model::Union{AbstractBackground, Nothing}, link_success_prob::Float64, seed::Int, logging::DataFrame, rounds::Int, graphdata::Any)
    
    # Set a random seed
    Random.seed!(seed)
    
    switch = Register(fill(Qubit(), n), fill(states_representation, n), fill(noise_model, n)) # storage qubits at the switch, where n qubits are not affected by noise
    clients = Register(fill(Qubit(), n),  fill(states_representation, n), fill(noise_model, n)) # client qubits
    net = RegisterNet([switch, clients])
    sim = get_time_tracker(net)

    # Start the piecemaker protocol
    @process GraphSequentialProt(sim, n, net, link_success_prob, logging, rounds, graphdata)
    return sim
end

nr = 2
const n, graphdata, _, projectors = get_graphdata_from_pickle("examples/graphstateswitch/input/3ghz.pickle")
states_representation = QuantumOpticsRepr()
number_of_samples = 10
seed = 42
df_all_runs = DataFrame()
for prob in [0.5]#range(0.1, stop=1, length=10) #cumsum([9/i for i in exp10.(range(1, 10, 10))])#
    for mem_depolar_prob in [0.1]#exp10.(range(-3, stop=0, length=30)) #[0.001, 0.0001, 0.00001]#

        logging = DataFrame(
            distribution_times  = Float64[],
            fidelities    = Float64[],
            chosen_vcs = [],
            edges = []
        )

        decoherence_rate = - log(1 - mem_depolar_prob)
        noise_model = Depolarization(1/decoherence_rate)
        sim = prepare_sim(n, states_representation, noise_model, prob, seed, logging, number_of_samples, graphdata)
        timed = @elapsed run(sim)

        logging[!, :elapsed_time] .= timed
        logging[!, :number_of_samples] .= number_of_samples
        logging[!, :link_success_prob] .= prob
        logging[!, :mem_depolar_prob] .= mem_depolar_prob
        logging[!, :num_remote_nodes] .= n
        logging[!, :seed] .= seed
        append!(df_all_runs, logging)
        @info "Mem depolar probability: $(mem_depolar_prob) | Link probability: $(prob)| Time: $(timed)"
    end
end
@info df_all_runs
#CSV.write("examples/graphstateswitch/output/factory/qs_graph$(nr)sequentialgeneraltest.csv", df_all_runs)