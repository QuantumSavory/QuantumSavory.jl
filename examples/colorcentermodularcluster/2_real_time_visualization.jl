@time include("setup.jl")
using GLMakie
GLMakie.activate!()

##

net, sim, observables, conf = prep_sim(root_conf)

F = Figure(resolution=(1500,800))

# Plot of the quantum states in the registers
subfig_rg, ax_rg, p_rg = registernetplot_axis(F[1:2,1],net)
registercoords = p_rg[:registercoords]

# Plots of various metadata and locks
subfig_res1, ax_res1, p_res1 = resourceplot_axis(F[1,2],
    net,
    [:link_queue], [:espin_queue,:nspin_queue,:decay_queue];
    registercoords=registercoords,
    title="Processes and Queues")
subfig_res2, ax_res2, p_res2 = resourceplot_axis(F[2,2],
    net,
    [:link_register], [];
    registercoords=registercoords,
    title="Established Links")

# A rather hackish and unstable way to add more information to the register plot
linkcolors = Observable(fill(0.0,nv(net)))
regcoords = p_rg[:registercoords]
for v in vertices(net)
    ls = linesegments!(ax_rg, regcoords[][vcat([[v,n] for n in neighbors(net,v)]...)].+(Point2f(0,1)+Point2f(rand()-0.5,rand()-0.5)/2),
        color=lift(x->fill(x[v],length(neighbors(net,v))),linkcolors),
        colormap = :Spectral,
        colorrange = (-1., 1.),
        linewidth=10,markerspace=Makie.SceneSpace)
    v==1 && Colorbar(subfig_rg[2,1],ls,vertical=false,flipaxis=false,label="Entanglement Stabilizer Expectation")
end

# Plot of the evolving mean fidelity with respect to time
ts = Observable(Float64[0])
fids = Observable(Float64[0])
fidsMax = Observable(Float64[0])
fidsMin = Observable(Float64[0])
g = F[1,3]
ax2 = Axis(g[1,1], xlabel="time (ms)", ylabel="Entanglement Stabilizer\nExpectation")
la = stairs!(ax2,ts,fids,linewidth=5,label="Average")
lb = stairs!(ax2,ts,fidsMax,color=:green,label="Best node")
lw = stairs!(ax2,ts,fidsMin,color=:red,label="Worst node")
Legend(g[2,1],[la,lb,lw],["Average","Best node","Worst node"],
    orientation = :horizontal, tellwidth = false, tellheight = true)
xlims!(0, nothing)
ylims!(-0.05, 1.05)

#=
lsgrid = labelslidergrid!(
    F,
    ["η", "τᴮᴷ", "T₁ⁿ", "pˡᵒᶜᵃˡ⁻ᵉʳʳ"],
    [1:1:100, 1:10, 200:2000, 0.01:0.01:1];
    formats = [
        x -> "$(round(x, digits = 1)) %",
        x -> "$(round(x, digits = 1)) μs",
        x -> "$(round(x, digits = 1)) ms",
        x -> "$(round(x, digits = 2)) %"
        ],
    width = 350,
    tellheight = false)
for (v,s) in zip([conf.BK_total_efficiency*100, conf.BK_electron_entanglement_gentime*1000, conf.T1N, 0.4],
                lsgrid.sliders)# TODO ugly
    set_close_to!(s, v)
end
F[2, 3] = lsgrid.layout
=#
display(F)

# Run the simulation
FRAMERATE = 10
tscale = conf.T2N*10
step_ts = range(0, 0.1*tscale, step=tscale/500)
record(F, "colorcentermodularcluster-02.simdashboard.mp4", step_ts, framerate=FRAMERATE) do t
    run(sim, t)
    for r in net.registers
        isassigned(r,2) && uptotime!([r],[2],now(sim))
    end
    fid = map(vertices(net)) do v
        neighs = neighbors(net,v)
        l = length(neighs)
        obs = observables[l]
        regs = [net[i, 2] for i in [v, neighs...]]
        real(observable(regs, obs, 0.0))
    end

    linkcolors[] .= fid
    push!(fids[],mean(fid))
    push!(fidsMax[],maximum(fid))
    push!(fidsMin[],minimum(fid))
    push!(ts[],now(sim))
    notify(ts)
    notify(linkcolors)
    notify(p_res2[1])
    xlims!(ax2,max(0,ts[][end]-conf.BK_mem_wait_time*5), nothing)
end

println(now(sim))
