include("setup.jl")

using GLMakie # For plotting
GLMakie.activate!()

##
# Demo the entangler on its own
##

sizes = [2,3,4,3,2]        # Number of qubits in each register
T2 = 10.0                  # T2 dephasing time of all qubits
#TODO F = 0.9                    # Fidelity of the raw Bell pairs

sim, network = simulation_setup(sizes, T2)

##

for (;src, dst) in edges(network)
    eprot = EntanglerProt(sim, network, src, dst)
    @process eprot()
end
for node in vertices(network)
    sprot = SwapperProt(sim, network, node; nodeL = <(node), nodeH = >(node), chooseL = argmin, chooseH = argmax)
    @process sprot()
end

##

# set up a plot and save a handle to the plot observable
fig = Figure(size=(400,400))
_,ax,_,obs = registernetplot_axis(fig[1,1],network)
display(fig)

##

# record the simulation progress
step_ts = range(0, 30, step=0.1)
record(fig, "firstgenrepeater-03.swapper.mp4", step_ts, framerate=10, visible=true) do t
    run(sim, t)
    notify(obs)
    ax.title = "t=$(t)"
end
