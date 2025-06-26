using CSV, DataFrames, Statistics
using StatsPlots           # re-exports plot, heatmap, etc.
using Plots                # so that `Plot` is in scope
using ColorSchemes         # for :RdBu
using Glob                 # for glob()
using LaTeXStrings

DATADIR = "/Users/localadmin/Library/CloudStorage/OneDrive-DelftUniversityofTechnology/2_backup_project_piecemaker/output_GHZ"

all_csvs = glob("*.csv", DATADIR)

function split_filename(path::AbstractString)
    name = Base.basename(path)    # use Base.basename on a String
    if occursin("_factory", name)
        return first(eachmatch(r"\d+", name)).match, :factory
    elseif occursin("_piecemaker", name)
        return first(eachmatch(r"\d+", name)).match, :piecemaker
    else
        return nothing, nothing
    end
end

# group into Dict(sample => Dict(proto=>path))
samples = Dict{String,Dict{Symbol,String}}()
for p in all_csvs
    sample, proto = split_filename(p)
    sample === nothing && continue
    samples[sample] = get(samples, sample, Dict{Symbol,String}())
    samples[sample][proto] = p
end

# keep only those with both factory & piecemaker
pairs = sort([ (k,v) for (k,v) in samples if (:factory in keys(v) && :piecemaker in keys(v)) ])

println("Found $(length(pairs)) samples: ", join(first.(pairs), ", "))
BYCOLS = [:mem_depolar_prob, :link_success_prob]

function diff_matrices(path_can::String, path_seq::String)
    # Read and scale data to match Python (scale by 100 and round)
    df_can = CSV.read(path_can, DataFrame)
    df_seq = CSV.read(path_seq, DataFrame)

    # Group and compute means
    m_can = combine(groupby(df_can, BYCOLS), :fidelities => mean => :fid_can)
    m_seq = combine(groupby(df_seq, BYCOLS), :fidelities => mean => :fid_seq)

    df = innerjoin(m_can, m_seq, on=BYCOLS)
    df.diff_abs = df.fid_seq .- df.fid_can
    df.diff_infid = @. df.diff_abs / (1. - df.fid_can) 

    # Pivot to matrix format
    function to_matrix(valcol)
        wide = unstack(df, :mem_depolar_prob, :link_success_prob, valcol)
        y = wide.mem_depolar_prob
        Z = Matrix(select(wide, Not(:mem_depolar_prob)))
        x_str = string.(names(wide)[2:end])  # Convert Symbols to Strings
        x = parse.(Float64, x_str)
        return x, y, Z
    end

    return [to_matrix(:diff_abs), to_matrix(:diff_infid)]
end

for (sample, paths) in pairs
    plots = []
    mats = diff_matrices(paths[:factory], paths[:piecemaker])
    
    for (j, (x, y, Z)) in enumerate(mats)
        p = heatmap(x, y, Z';
                    title = j == 1 ? L"$F_{pm} - F_{factory}$" : L"$(F_{pm} - F_{factory})/(1 - F_{factory})$",
                    xscale=:log10, yscale=:log10,
                    xlabel=L"$p_{depol}$",
                    ylabel=L"$p_{link}$",
                    colorbar = true,
                    protrusions=0)
        push!(plots, p)
    end
    fig = plot(plots...,
        layout = (1, 2),
        margin=2*Plots.mm)

    savefig(fig, "sample_$(sample)GHZ_diff_heatmaps.pdf")
end