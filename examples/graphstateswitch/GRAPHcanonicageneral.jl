
include("utils.jl")

@resumable function entangle(sim, net, switchidx, idx, link_success_prob)
    entangler = EntanglerProt(
        sim=sim, net=net, nodeA=switchidx, slotA=idx, nodeB=idx+1, slotB=1,
        success_prob=link_success_prob, rounds=1, attempts=-1, attempt_time=1.0,
        )
    @yield @process entangler()
end

@resumable function apply_correction(sim, net, idx)
    messagebuffer = messagebuffer(net[idx+1])
    while true
        @yield wait(messagebuffer)
        msg = querydelete!(messagebuffer, :measx, ❓)
        !isnothing(msg) && begin 
            _, xmeas_outcome =  msg.tag
            @yield lock(net[idx+1][1])
            xmeas_outcome == 2 && apply!(net[idx+1][1], Z)
            put!(channel(net, idx+1=>1), Tag(:corrected))
            unlock(net[idx+1][1])
            break
        end
    end
end

@resumable function apply_cz_and_measure(sim, net, idx, graph)
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
    @yield lock(net[1][idx])
    xmeas = project_traceout!(net[1][idx], σˣ)
    unlock(net[1][idx])
    put!(channel(net, 1=>idx+1), Tag(:measx, xmeas))
end

@resumable function logger(sim, net, logging, vcs)
    # Wait until all clients have been corrected
    corrected = 0
    while corrected < n
        @info corrected
        @yield wait(messagebuffer(net[1]))
        if !isnothing(querydelete!(messagebuffer(net[1]), :corrected))
            corrected += 1
        else
            continue
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

@resumable function GraphCanonicalProt(sim, n, net, vcs, cover_idx)

    start = now(sim)
    graph = Graph() # general graph object, to be later replaced by chosen state
    counter_clients = 0 # counts clients that are entangled
    active = Set{Int}() # qubits that have an EPR pair 
    cover_idx = nothing # index in vcs (fixed once)

    while counter_clients < n

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
        if isnothing(cover_idx) # take same graph as in the sequential case
            cover_idx = findfirst(vcs) do cover # check if a core is present
                cover ⊆ active
            end 
        end
        isnothing(cover_idx) && continue 
        graph = deepcopy(graphdata[vcs[cover_idx]]) # graph to be generated
        put!(channel(net, 1=>2), Tag(:cover, cover_idx))
    end

    # If all clients have established their link-level entanglement
    for idx in 1:n
        @yield @process apply_cz_and_measure(sim, net, idx, graph) # apply CZ gates, measure and send the result to the client
    end

end

function prepare_sim(n::Int, states_representation::AbstractRepresentation, noise_model::Union{AbstractBackground, Nothing}, link_success_prob::Float64, seed::Int, logging::DataFrame, graphdata::Any)

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

    # Each client applies a correction
    for i in 1:n
        @process apply_correction(sim, net, i)
    end

    # Start the piecemaker protocol on the switch
    @process GraphCanonicalProt(sim, n, net, vcs, logging)

    @process logger(sim, net, logging, vcs)

    return sim
end


nr = 4
const n, graphdata, _, projectors = get_graphdata_from_pickle("examples/graphstateswitch/input/$(nr).pickle")
@info n
states_representation = QuantumOpticsRepr() #
number_of_samples = 10
seed = 42

# Set a random seed
Random.seed!(seed)

df_all_runs = DataFrame()
times = Float64[]
for prob in [0.5]#range(0.1, stop=1, length=10) #cumsum([9/i for i in exp10.(range(1, 10, 10))])#
    for mem_depolar_prob in [0.1]#exp10.(range(-3, stop=0, length=30)) #[0.001, 0.0001, 0.00001]#

        logging = DataFrame(
            distribution_times  = Float64[],
            fidelities    = Float64[]
        )
        decoherence_rate = - log(1 - mem_depolar_prob)
        noise_model = Depolarization(1/decoherence_rate)
        for i in 1:number_of_samples
            sim = prepare_sim(n, states_representation, noise_model, prob, seed, logging, graphdata)
        
            timed = @elapsed run(sim)
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
        @info "Mem depolar probability: $(mem_depolar_prob) | Link probability: $(prob)| Time: $(sum(times))"
    end
end
@info df_all_runs
#CSV.write("examples/graphstateswitch/output/factory/qs_graph$(nr)canonicalgeneral_sweep.csv", df_all_runs)