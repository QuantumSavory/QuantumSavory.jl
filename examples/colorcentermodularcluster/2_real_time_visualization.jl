include("setup.jl")
using GLMakie
GLMakie.activate!()

##

net, sim, observables, conf = prep_sim(root_conf)

F = Figure(resolution=(1500,800))

# Plot of the quantum states in the registers
subfig_rg, ax_rg, p_rg, obs_rg = registernetplot_axis(F[1:2,1],net)
registercoords = p_rg[:registercoords]

# Plots of various metadata and locks
_,_,_,obs_1 = resourceplot_axis(F[1,2],
    net,
    [:link_queue], [:espin_queue,:nspin_queue,:decay_queue];
    registercoords=registercoords,
    title="Processes and Queues")
_,_,_,obs_2 = resourceplot_axis(F[2,2],
    net,
    [:link_register], [];
    registercoords=registercoords,
    title="Established Links")

# A rather hackish and unstable way to add more information to the register plot
# This plot will overlay with colored lines the fidelity of entanglement of each node
linkcolors = Observable(fill(0.0,nv(net)))
regcoords = p_rg[:registercoords]
for (i,v) in enumerate(vertices(net))
    offset = Point2(0,1).+0.1*(i%7-4)
    ls = linesegments!(ax_rg, regcoords[][vcat([[v,n] for n in neighbors(net,v)]...)].+(offset),
        color=lift(x->fill(x[v],length(neighbors(net,v))),linkcolors),
        colormap = :Spectral,
        colorrange = (-1., 1.),
        linewidth=3,markerspace=:data)
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

display(F)

# Run the simulation
FRAMERATE = 10
tscale = conf[:T₂ⁿ]/3
step_ts = range(0, tscale, step=tscale/500)
record(F, "colorcentermodularcluster-02.simdashboard.mp4", step_ts, framerate=FRAMERATE) do t
    run(sim, t)

    # calculate the fidelities for each node of the cluster state
    fid = map(vertices(net)) do v
        neighs = neighbors(net,v)
        l = length(neighs)
        obs = observables[l]
        regs = [net[i, 2] for i in [v, neighs...]]
        real(observable(regs, obs, 0.0; time=now(sim)))
    end
    linkcolors[] .= fid
    push!(fids[],mean(fid))
    push!(fidsMax[],maximum(fid))
    push!(fidsMin[],minimum(fid))
    push!(ts[],now(sim))

    # update plots
    notify(ts)
    notify(linkcolors)
    notify(obs_rg)
    notify(obs_1)
    notify(obs_2)
    xlims!(ax2,max(0,ts[][end]-2*conf[:T₂ⁿ]), nothing)
end
