using ThreadTools
using Base.Threads
using DataFrames
using CairoMakie
CairoMakie.activate!()

include("setup.jl");

"""Run a simulation until all links in the cluster state are established,
then report time to completion and average link fidelity."""
function run_until_connected(root_conf)
    net, sim, observables, conf = prep_sim(root_conf)
    # Run until all connections succeed
    while !all([net[v,:link_register] for v in edges(net)])
        SimJulia.step(sim)
    end
    # Calculate fidelity of each cluster vertex
    fid = map(vertices(net)) do v
        neighs = neighbors(net,v) # get the neighborhood of the vertex
        obs = observables[length(neighs)] # get the observable for the given neighborhood size
        regs = [net[i, 2] for i in [v, neighs...]]
        real(observable(regs, obs; time=now(sim))) # calculate the value of the observable
    end
    now(sim), mean(fid)
end

# Run a quick check that the simulation works.
# The first run will be slow as the code has to first compile.
@time run_until_connected(root_conf)

##
# Run a hundred simulations in multiple parallel threads
# and store the results in a dataframe.

@time r = tmap((_)->run_until_connected(root_conf), 1:100);
df = rename(DataFrame(r), [:time,:fid])

##
# Plot the time to complete vs average fidelity

F = Figure(resolution=(600,600))
F1 = F[1,1]
ax = Axis(F1[2:5,1:4])
ax_time = Axis(F1[1,1:4])
ax_fid = Axis(F1[2:5,5])
linkxaxes!(ax,ax_time)
linkyaxes!(ax,ax_fid)
scatter!(ax, df.time, df.fid)
hist!(ax_time, df.time)
hist!(ax_fid, df.fid, direction=:x)
hidexdecorations!(ax_fid)
hideydecorations!(ax_time)
ax.ylabel = "Fidelity"
ax.xlabel = "Time to cluster prep"
F
save("colorcentermodularcluster-01.timetoconnection.png", F)
