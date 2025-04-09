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
        "--protocol"
            help = "protocol to run, choose between 'sequential' and 'canonical'"
            default = "canonical"
            arg_type = String
        "--noise"
            help = "Noise to be modeled, choose between 'nothing', 'Depolarization' and 'T2Dephasing'"
            default = "Depolarization"
            arg_type = String
        "--nr"
            help = "graph id"
            default = 2
            arg_type = Int
        "--nruns"
            help = "number of runs"
            arg_type = Int
            default = 10
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

# Load protocol
protocol = parsed_args["protocol"]
if protocol == "sequential"
    include("protocol_sequential.jl")
elseif protocol == "canonical"
    include("protocol_canonical.jl")
else
    error("Invalid protocol specified. Use 'sequential' or 'canonical'.")
end

# Set global variables
rounds = parsed_args["nruns"]
nr = parsed_args["nr"]
seed = parsed_args["seed"]
output_path = parsed_args["output_path"]

probs = exp10.(range(-3, stop=0, length=30))
ts = exp10.(range(1, stop=3, length=30))
max_prob = maximum(probs)

noise_model = parsed_args["noise"]

# Graph state data
path_to_graph_data = "examples/graphstateswitch/input/$(nr).pickle"
graphdata, _ = get_graphdata_from_pickle(path_to_graph_data)

# Run simulation experiments for differnt noise models
all_runs = DataFrame()
for t in ts # Noise time

    # Noise model
    if noise_model == "Depolarization"
        noise = Depolarization(t)
    elseif noise_model == "T2Dephasing"
        noise = T2Dephasing(t)
    elseif noise_model == "nothing"
        noise = nothing
    else
        error("Invalid noise model specified. Use 'nothing', 'Depolarization' or 'T2Dephasing'.")
    end
    
    for link_success_prob in probs

        ref_core = first(keys(graphdata)) # the first key is the reference core
        n = nv(graphdata[ref_core][1]) # number of clients taken from one example graph

        logging = DataFrame(
            sim_time    = Float64[],
            coincide    = Float64[],
            H_idx = Any[],
            S_idx = Any[],
            Z_idx = Any[],
            fidelity    = Float64[]
        )
        # for i in 1:n
        #     logging[!, Symbol("eig", i)] = Float64[]
        # end

        if protocol == "sequential"
            logging[!, :chosen_core] = Tuple[]
        end

        if protocol == "canonical"
            g = graphdata[ref_core]
            sim = prepare_sim(n, noise, g, link_success_prob, seed, logging, rounds)
        else 
            sim = prepare_sim(n, noise, graphdata, link_success_prob, seed, logging, rounds)
        end
        timed = @elapsed run(sim)

        if protocol == "canonical"
            logging[!, :chosen_core]    .= Ref(ref_core)
        end
        logging[!, :elapsed_time]       .= timed
        logging[!, :link_success_prob]  .= link_success_prob
        logging[!, :noise_time]       .= t
        logging[!, :graph_id]           .= nr
        logging[!, :seed]               .= seed
        logging[!, :nqubits]            .= n
        append!(all_runs, logging)
        @info "Link success probability: $(link_success_prob) | Time: $(timed)"
    end
end
@info all_runs
CSV.write(output_path*"$(protocol)_clifford_nr$(nr)_$(noise_model)_until$(max_prob).csv", all_runs)