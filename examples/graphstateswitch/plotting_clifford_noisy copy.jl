using CSV, DataFrames, Plots, StatsPlots, Statistics, StatsBase
using YAML 

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
function get_plot_df(graph_id::Int, noise::String, splits::Array{Symbol}, cols::Array{String}; overall::Bool=true, path_config::String="examples/graphstateswitch/plotconfigs.yaml", stats::Array{Function}=[mean, sem], compute_stats::Bool=true)
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
            input_file_pattern = "$(protocol)_clifford_noisy_nr$(graph_id)_$(read_mapping[noise])($(noise_time))_until0.1.csv"
            df = CSV.read("examples/graphstateswitch/output/"*input_file_pattern, DataFrame)
            
            if compute_stats
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
            else
                df_stats = df
            end

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
            #df_stats[!, :nqubits] .= n
        
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
            # ylim = (0, 1),
            xscale = :log10,
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
    
    plt = plot(layout = (div(n_subplots,2), 2), size = (1000, 700), left_margin = 10Plots.mm)
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
            #ylim = (0, 1),
            xscale = :log10,
            yerr = cols(findfirst(columns.=="sem_"*take_meas)),  # sem_eig or sem_fidelity
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

noise_models = ["T", "τ"] # use "τ" for depolarizing noise, "T" for dephasing noise
splits = [:link_success_prob]
cols = ["eig", "fidelity"]

# for noise in noise_models
#     for graph_id in [2, 4, 7, 8, 9, 18, 40, 100]
#         data = get_plot_df(graph_id, noise, splits, cols; overall=true, path_config="examples/graphstateswitch/plotconfigs.yaml", stats=[mean, sem])
#         plot_data(data, noise, "eig", disp=true, saveplot=true) # use "fidelity" for fidelity
#         plot_data(data, noise, "fidelity", disp=true, saveplot=true) 
#         plot_data(data, noise; disp=true, saveplot=true) # plot all stabilizer eigenvalues
#     end
# end

# plt = plot(layout = (4, 2), size = (1000, 1500), margin = 10Plots.mm)
# for (i, id) in enumerate([2, 4, 7, 8, 9, 18, 40, 100])
#     data = get_plot_df(id, "τ", splits, cols; overall=false, path_config="examples/graphstateswitch/plotconfigs.yaml", stats=[mean, sem])
#     df_plot = data[data[!, :τ] .== 1000.0, :]
#     n = unique(data.nqubits)[1]
#     @df df_plot groupedbar!(plt,
#         :link_success_prob,
#         :mean_fidelity,
#         group=:type,
#         xlabel = "Link Success Probability",
#         ylabel = "Mean Fidelity",
#         title = "Graph nr. $(id) ($(n) qubits)",
#         legend = :right,
#         # ylim = (0, 1),
#         #xscale = :log10,
#         bar_position = :dodge,
#         bar_width = 0.002,
#         framestyle = :box,
#         lw = 0,
#         margin = 10Plots.mm,
#         subplot = i
#     )
# end

# display(plt)

t = 100.0 # 1000.0
noise = "τ"

data = get_plot_df(id, noise, [:link_success_prob], ["eig1", "eig2"], overall=false, path_config="examples/graphstateswitch/plotconfigs.yaml", stats=[mean, sem], compute_stats=false)

plt = plot(layout = (4, 2), size = (1000, 1500), margin = 10Plots.mm)
plt[:plot_title] = "Fidelity counts with $(noise) = $t\n over all link success probabilities in [$(minimum(data.link_success_prob)), $(maximum(data.link_success_prob))]"

for (i, id) in enumerate([2, 4, 7, 8, 9, 18, 40, 100])
    n = unique(data.nqubits)[1]
    df_plot = data[data[!, Symbol(noise)] .== t, :]
    @df df_plot groupedhist!(
        :fidelity, 
        group=:type, 
        xlabel="Fidelity", 
        ylabel="Density", 
        title="Graph $(id) ($(n) qubits)", 
        legend=:top,
        subplot = i,
        bar_position = :dodge,
        nbins = 10,
        bar_width = 0.2,
        )
end
display(plt)
savefig(plt, "examples/graphstateswitch/BARS_fidelity_different_$(noise)__comparison.pdf")