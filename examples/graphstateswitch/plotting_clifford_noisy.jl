using CSV, DataFrames, Plots, StatsPlots, Statistics, StatsBase
using YAML 
using LaTeXStrings

"""
    get_statistics(df, [:link_success_prob], ["eig1", "eig2"], [mean, sem])

Computes stats (an array of statistical functions e.g., `mean`, `sem`) for given columns `cols` `["eig1", "eig2"]` 
grouped by given other columns `splits` `[:link_success_prob]`. The result is a DataFrame with the computed statistics.
The columns of the DataFrame are named as `statistic_column` (`mean_eig1`, `sem_eig2`).
"""
function get_statistics(df::DataFrame, splits::Array{Symbol}, cols::Array{String}, stats::Array{Function})

    stats_to_combine = []
    for col in cols
        # Check if the column exists in the DataFrame
        if col in names(df)
            # Compute the statistic for the column
            for stat in stats
                push!(stats_to_combine, Symbol(col) => stat => Symbol(String(Symbol(stat))*"_", col))
            end
        else
            @warn "Column $(col) not found in DataFrame"
        end
    end
    combine(groupby(df, splits), stats_to_combine...)
end

"""
    get_plot_df(2; overall=true, path_config="examples/graphstateswitch/plotconfigs.yaml")

Get the DataFrame for plotting. If there are more granular statistics, one can use `overall=true` to calculate a row-wise mean of the latter.
Uses the `get_statistics` function to compute the mean and sem of the stabilizer eigenvalues.
"""
function get_plot_df(graph_id::Int, noise::String, splits::Array{Symbol}, cols::Array{String}; overall::Bool=true, path_config::String="examples/graphstateswitch/plotconfigs.yaml", stats::Array{Function}=[mean, sem])
    yaml_mapping = Dict(
        "τ" => "depol",
        "T" => "dephasing",
    )
    read_mapping = Dict(
        "τ" => "Depolarization",
        "T" => "T2Dephasing",
    )
    configs = YAML.load_file(path_config)
    protocols = configs["protocol"]
    noise_times = configs[yaml_mapping[noise]]

    dfs = DataFrame[]
    for noise_time in noise_times
        for protocol in protocols
        # Read the raw data
            input_file_pattern = "$(protocol)_clifford_noisy_nr$(graph_id)_$(noise)$(noise_time).csv"
            df = CSV.read("/Users/localadmin/Documents/github/output/$(protocol)_clifford_nr$(graph_id)_$(read_mapping[noise])($(noise_time))_until1.0.csv", DataFrame)
        
            # Count how many unique measures there are
            cnames = []
            n = 0
            for col in cols
                cols_to_take = names(df, x -> startswith(x, col))
                push!(cnames, cols_to_take)
                if length(cols_to_take) > n # assuming that most granular performance measure counts the number of qubits
                    n = length(cols_to_take)
                end
            end
        
            # Group and produce mean/sem of each eigᵢ column
            df_stats = get_statistics(df, splits, vcat(cnames...) , stats)
        
            if overall
                for (col, c) in zip(cols, cnames)
                    # Only do if there is more than one column
                    if length(c) > 1
                        for stat in stats
                            # d will be the list of “stat_*” columns that correspond to c
                            d = (string(stat) * "_") .* c
                            
                            # Create a new column in df_stats that’s the per-row result of “stat”
                            df_stats[!, Symbol(stat, "_", col)] =
                                map(mean, eachrow(select(df_stats, d...)))
                        end
                    end
                end
            end

            df_stats[!, :graph_id] .= graph_id
            df_stats[!, Symbol(noise)] .= noise_time
            df_stats[!, :type] .= protocol
            df_stats[!, :nqubits] .= n
        
            # Push the result into dfs
            push!(dfs, df_stats)
        end
    end
    # Concatenate all the dataframes
    data = vcat(dfs...)
    data
end

"""
    Plot mean of stabilizer eigenvalues for different noise_time times. 
"""
function plot_data(data::DataFrame, noise::String; disp::Bool=true, saveplot::Bool=false)
    graph_id = unique(data.graph_id)[1]
    n = unique(data.nqubits)[1]
    noise_time_values = unique(data[!, Symbol(noise)])
    n_subplots = length(noise_time_values)
    
    plt = plot(layout = (div(n_subplots,2), 2), size = (1000, 700), left_margin = 10Plots.mm)
    plt[:plot_title] = "Graph nr. $(graph_id) ($(n) qubits)"
    for (i, t) in enumerate(noise_time_values)
        # Subset the data for noise_time == t and id_graph
        df_sub = data[(data[!, Symbol(noise)] .== t) .& (data[!, :type] .== "sequential"), :]

        mean_cols = [Symbol("mean_eig", i) for i in 1:n]
        sem_cols  = [Symbol("sem_eig", i) for i in 1:n]
    
        @df df_sub plot!(plt,
            :link_success_prob,
            cols(mean_cols),  # mean_eig or fidelity
            group = :type,           # color by canonical or sequential
            subplot = i,           # tell Plots.jl which subplot to draw on
            xlabel = "Link Success Probability",
            ylabel = "Stabilizer eigenvalues +/- SEM",
            title = "noise_time = $t",
            legend = :right,
            ylim = (0, 1),
            yerr = cols(sem_cols),  # sem_eig or sem_fidelity
        )
    end
    if disp
        display(plt)
    end
    if saveplot
        savefig(plt, "examples/graphstateswitch/output/stabeigenvalues_different_$(noise)_$(graph_id).pdf")
    end
end

"""
    Plot overall mean fidelity or mean stabilizer eigenvalues.
"""
function plot_data(data::DataFrame, noise::String, take_meas::String; disp::Bool=true, saveplot::Bool=false)
    graph_id = unique(data.graph_id)[1]
    n = unique(data.nqubits)[1]
    noise_time_values = unique(data[!, Symbol(noise)])
    n_subplots = length(noise_time_values)
    
    plt = plot(size = (1000, 500), left_margin = 10Plots.mm) #layout = (div(n_subplots,2), 2), 
    plt[:plot_title] = "Graph nr. $(graph_id) ($(n) qubits)"
    for (i, t) in enumerate(noise_time_values)
        # Subset the data for noise_time == t and id_graph
        df_sub = data[(data[!, Symbol(noise)] .== t), :]

        columns = collect(names(df_sub))
        @df df_sub plot!(plt,
            :link_success_prob,
            cols(findfirst(columns.=="mean_"*take_meas)),  # mean_eig or fidelity
            group = :type,           # color by canonical or sequential
            subplot = i,           # tell Plots.jl which subplot to draw on
            xlabel = "Link Success Probability",
            ylabel = take_meas*" mean +/- SEM",
            title = "$(noise) = $t",
            legend = :right,
            xscale = :log10,
            ylim = (0, 1),
            yerr = cols(findfirst(columns.=="sem_"*take_meas)),  # sem_eig or sem_fidelity
            margin = 5Plots.mm,
            xticks = [0.001, 0.01, 0.1, 1],
        )
    end
    if disp
        display(plt)
    end
    if saveplot
        savefig(plt, "examples/graphstateswitch/output/$(take_meas)_different_$(noise)_$(graph_id)_comparison.pdf")
    end
end

# Main plotting script

# noise_models = ["τ"] # use "τ" for depolarizing noise, "T" for dephasing noise
# splits = [:link_success_prob]
# cols = ["eig", "fidelity"]

# for noise in noise_models
#     for graph_id in [18]#[2, 4, 7, 8, 9, 18, 40, 100]
#         data = get_plot_df(graph_id, noise, splits, cols; overall=true, path_config="examples/graphstateswitch/plotconfigs.yaml", stats=[mean, sem])
#         #plot_data(data, noise, "eig", disp=true, saveplot=true) # use "fidelity" for fidelity
#         plot_data(data, noise, "fidelity", disp=true, saveplot=true) 
#         #plot_data(data, noise; disp=true, saveplot=true) # plot all stabilizer eigenvalues
#     end
# end



graph_id = 8
dfseq = CSV.read("/Users/localadmin/Documents/github/output/sequential_clifford_nr$(graph_id)_Depolarization_until1.0.csv", DataFrame)
dfcan = CSV.read("/Users/localadmin/Documents/github/output/canonical_clifford_nr$(graph_id)_Depolarization_until1.0.csv", DataFrame)

noise_times = exp10.(range(1, stop=3, length=30))
link_success_probs = exp10.(range(-3, stop=0, length=30))

data_sequential = get_statistics(dfseq, [:link_success_prob, :noise_time], ["fidelity"], [mean, sem])
data_canonical = get_statistics(dfcan, [:link_success_prob, :noise_time], ["fidelity"], [mean, sem])

diff = (data_sequential.mean_fidelity .- data_canonical.mean_fidelity)./ (1.0 .-data_canonical.mean_fidelity)
diff .= (diff .> 0.0) .* diff # set negative values to zero

data = rand(21,100)
plt = heatmap(noise_times, link_success_probs, reshape(diff, 30, 30),
    xlabel="τ", ylabel="link success probability",
    xscale=:log10, yscale=:log10,
    title=L"$\frac{\overline{F}_{seq} - \overline{F}_{can}}{1-\overline{F}_{can}}$",
    margin = 10Plots.mm,)
savefig(plt, "examples/graphstateswitch/output/heatmap_different_τ_$(graph_id)_comparison.pdf")


