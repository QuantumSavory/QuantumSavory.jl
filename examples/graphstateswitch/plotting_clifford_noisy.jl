using CSV, DataFrames, Plots, StatsPlots, Statistics, StatsBase
using YAML 

"""
    get_statistics(df, [:link_success_prob], ["eig1", "eig2"], [mean, sem])

Computes stats (an array of statistical functions e.g., `mean`, `sem`) for given columns `cols` `["eig1", "eig2"]` 
grouped by given other columns `splits` `[:link_success_prob]`. The result is a DataFrame with the computed statistics.
The columns of the DataFrame are named as `statistic_column` (`mean_eig1`, `sem_eig2`).
"""
function get_statistics(df::DataFrame, splits::Array{Symbol}, cols::Array{Any}, stats::Array{Function})

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
function get_plot_df(graph_id::Int, splits::Array{Symbol}, cols::Array{String}; overall::Bool=true, path_config::String="examples/graphstateswitch/plotconfigs.yaml", stats::Array{Function}=[mean, sem])
    
    configs = YAML.load_file(path_config)
    protocols = configs["protocol"]
    T2s = configs["T2"]

    dfs = DataFrame[]
    for T2 in T2s
        for protocol in protocols
        # Read the raw data
            input_file_pattern = "$(protocol)_clifford_noisy_nr$(graph_id)_T$(T2).csv"
            df = CSV.read("examples/graphstateswitch/output/raw/T2dephasing_canonical_vs_sequential/"*input_file_pattern, DataFrame)
        
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
                    # Only do something if there is more than one “granular” column
                    if length(c) > 1
                        for stat in stats
                            # d will be the list of “stat_*” columns that correspond to c
                            d = (string(stat) * "_") .* c
                            
                            # Now create a new column in df_stats that’s the per-row result of “stat”
                            df_stats[!, Symbol(stat, "_", col)] =
                                map(stat, eachrow(select(df_stats, d...)))
                        end
                    end
                end
            end

            df_stats[!, :graph_id] .= graph_id
            df_stats[!, :T2] .= T2
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
    Plot mean of stabilizer eigenvalues for different T2 times. 
"""
function plot_data(data::DataFrame; disp::Bool=true, saveplot::Bool=false)
    graph_id = unique(data.graph_id)[1]
    n = unique(data.nqubits)[1]
    t2_values = unique(data.T2)
    n_subplots = length(t2_values)
    
    plt = plot(layout = (div(n_subplots,2), 2), size = (1000, 700), left_margin = 10Plots.mm)
    plt[:plot_title] = "Graph nr. $(graph_id) ($(n) qubits)"
    for (i, t) in enumerate(t2_values)
        # Subset the data for T2 == t and id_graph
        df_sub = data[(data.T2 .== t), :]

        mean_cols = [Symbol("mean_eig", i) for i in 1:n]
        sem_cols  = [Symbol("sem_eig", i) for i in 1:n]
    
        @df df_sub plot!(plt,
            :link_success_prob,
            cols(mean_cols),  # mean_eig or fidelity
            group = :type,           # color by canonical or sequential
            subplot = i,           # tell Plots.jl which subplot to draw on
            xlabel = "Link Success Probability",
            ylabel = "Stabilizer eigenvalues +/- SEM",
            title = "T2 = $t",
            legend = :right,
            ylim = (0, 1),
            yerr = cols(sem_cols),  # sem_eig or sem_fidelity
        )
    end
    if disp
        display(plt)
    end
    if saveplot
        savefig(plt, "examples/graphstateswitch/output/stabeigenvalues_different_T2_$(id_graph).pdf")
    end
end

"""
    Plot overall mean fidelity or mean stabilizer eigenvalues.
"""
function plot_data(data::DataFrame, take_meas::String; disp::Bool=true, saveplot::Bool=false)
    graph_id = unique(data.graph_id)[1]
    n = unique(data.nqubits)[1]
    t2_values = unique(data.T2)
    n_subplots = length(t2_values)
    
    plt = plot(layout = (div(n_subplots,2), 2), size = (1000, 700), left_margin = 10Plots.mm)
    plt[:plot_title] = "Graph nr. $(graph_id) ($(n) qubits)"
    for (i, t) in enumerate(t2_values)
        # Subset the data for T2 == t and id_graph
        df_sub = data[(data.T2 .== t), :]

        columns = collect(names(df_sub))
        @df df_sub plot!(plt,
            :link_success_prob,
            cols(findfirst(columns.=="mean_"*take_meas)),  # mean_eig or fidelity
            group = :type,           # color by canonical or sequential
            subplot = i,           # tell Plots.jl which subplot to draw on
            xlabel = "Link Success Probability",
            ylabel = take_meas*"_mean +/- SEM",
            title = "T2 = $t",
            legend = :right,
            ylim = (0, 1),
            yerr = cols(findfirst(columns.=="sem_"*take_meas)),  # sem_eig or sem_fidelity
        )
    end
    if disp
        display(plt)
    end
    if saveplot
        savefig(plt, "examples/graphstateswitch/output/$(take_meas)_different_T2_$(id_graph)_comparison.pdf")
    end
end


id_graph = 2
splits = [:link_success_prob]
cols = ["eig", "fidelity"]

data = get_plot_df(id_graph, splits, cols; overall=true, path_config="examples/graphstateswitch/plotconfigs.yaml", stats=[mean, sem])
plot_data(data, disp=true, saveplot=false)
