
include("utils.jl")

@resumable function GraphCanonicalProt(sim, n, net, link_success_prob, logging, rounds, graphdata)

    while rounds != 0
        start = now(sim)

        # Start entanglement generation for each client
        for i in 1:n
            @process entangle(sim, net, i, link_success_prob)
        end
        
        # graph = Graph()
        # add_vertices!(graph, n)
        # for i in 1:n-1
        #     add_edge!(graph, (i, i+1))
        # end

        vcs = collect(keys(graphdata)) # vertex covers TODO: can this be prettier?
        graph = Graph() # general graph object, to be later replaced by chosen state
        refgraph = Graph() # reference graph

        cover_idx = nothing # index in vcs (fixed once)
        counter_clients = 0 # counts clients that are entangled
        active = Set{Int}() # qubits that have an EPR pair 

        while counter_clients < n

            @yield onchange_tag(net[1])
            while true # until the query returns nothing
                counterpart = querydelete!(net[1], EntanglementCounterpart, ❓, ❓)
                if !isnothing(counterpart)
                    slot, _, tag = counterpart
                    push!(active, slot.idx)
                    counter_clients += 1
                else
                    break
                end
            end
            if isnothing(cover_idx) # take same graph as in the sequential case
                cover_idx = findfirst(vcs) do cover # check if a core is present
                    cover ⊆ active
                end 
            end
            isnothing(cover_idx) && continue 
            refgraph = graphdata[vcs[cover_idx]]
            graph = deepcopy(refgraph) # graph to be generated

        end

        # If all clients have established their link-level entanglement teleport state
        for idx in 1:n
            neighs = neighbors(graph, idx)
            @debug "neighbors of $(idx): ", neighs
            while !isempty(neighs)
                nb = neighs[1]
                apply!((net[1][idx], net[1][nb]), ZCZ; time=now(sim))
                @debug "apply CZ to $(idx) and $(nb)"
                rem_edge!(graph, idx, nb)
            end
            ( project_traceout!(net[1][idx], σˣ) == 2 ) &&
                apply!(net[2][idx], Z) # measure out the non-cover qubit
        end
        @yield reduce(&, [lock(q) for q in net[2]])
        obs = projector(StabilizerState(Stabilizer(refgraph)))
        result = observable([net[2][i] for i in 1:n], obs; time=now(sim))
        fidelity = sqrt(result'*result)

        foreach(q -> (traceout!(q); unlock(q)), net[2])

        # Log outcome
        push!(
            logging,
            (
                now(sim)-start, fidelity
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
    @process GraphCanonicalProt(sim, n, net, link_success_prob, logging, rounds, graphdata)
    return sim
end


nr = 7
states_representation = QuantumOpticsRepr()#
number_of_samples = 1000
seed = 42
df_all_runs = DataFrame()
for prob in range(0.1, stop=1, length=10)
    for mem_depolar_prob in exp10.(range(-3, stop=0, length=30))

        logging = DataFrame(
            distribution_times  = Float64[],
            fidelities    = Float64[]
        )
        n, graphdata, _ = get_graphdata_from_pickle("examples/graphstateswitch/input/$(nr).pickle")
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
#@info df_all_runs
CSV.write("examples/graphstateswitch/output/factory/qs_graph$(nr)canonicalgeneral_sweep.csv", df_all_runs)