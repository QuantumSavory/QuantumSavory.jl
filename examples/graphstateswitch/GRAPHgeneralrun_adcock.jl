include("GRAPHgeneralutils.jl") # to import graphdata from pickle files

# load protocol
protocol = parsed_args["protocol"]
if protocol == "sequential"
    Prot = GraphSequentialProt
elseif protocol == "canonical"
    Prot = GraphCanonicalProt
else
    error("Invalid protocol specified. Use 'sequential' or 'canonical'.")
end

# input file
folder_path = "examples/graphstateswitch/input/"
input_path = joinpath(pwd(), folder_path)
files = filter(x -> occursin("pickle", x), readdir(input_path))

filename = files[parsed_args["file_index"]]
file = joinpath(input_path, filename)

# load graph data
const n, graphdata, _, projectors = get_graphdata_from_pickle(file)
states_representation = CliffordRepr()
number_of_samples = parsed_args["nsamples"]

# set a random seed
seed = parsed_args["seed"]
Random.seed!(seed)

df_all_runs = DataFrame()
for link_success_prob in exp10.(range(-3, stop=0, length=20))
    for mem_depolar_prob in exp10.(range(-3, stop=0, length=20)) 

        logging = DataFrame(
            distribution_times  = Float64[],
            fidelities    = Float64[]
        )
        decoherence_rate = - log(1 - mem_depolar_prob)
        noise_model = Depolarization(1/decoherence_rate)

        vcs = collect(keys(graphdata)) # vertex covers TODO: can this be prettier?

        times = Float64[]
        for i in 1:number_of_samples
            sim = prepare_sim(Prot, n, states_representation, noise_model, link_success_prob, logging, vcs)
        
            timed = @elapsed run(sim) # time and run the simulation
            push!(times, timed)
            @debug "Sample $(i) finished", timed
        end

        logging[!, :elapsed_time] .= times
        logging[!, :number_of_samples] .= number_of_samples
        logging[!, :link_success_prob] .= link_success_prob
        logging[!, :mem_depolar_prob] .= mem_depolar_prob
        logging[!, :num_remote_nodes] .= n
        logging[!, :seed] .= seed
        append!(df_all_runs, logging)
        @debug "Mem depolar probability: $(mem_depolar_prob) | Link probability: $(link_success_prob)| Time: $(sum(times))"
    end
end
@show df_all_runs
#CSV.write(parsed_args["output_path"] * "$(replace(filename, ".pickle" => ""))_$(protocol)_seed$(seed).csv", df_all_runs)