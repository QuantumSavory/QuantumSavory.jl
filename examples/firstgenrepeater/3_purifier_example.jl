include("setup.jl")

using GLMakie # For plotting
GLMakie.activate!()

##
# Demo all three components, Entangler, Swapper, and Purifer working together
##
sizes = [2,3,4,3,2]        # Number of qubits in each register
T2 = 10.0                  # T2 dephasing time of all qubits
F = 0.9                    # Fidelity of the raw Bell pairs
entangler_wait_time = 0.1  # How long to wait if all qubits are busy before retring entangling
entangler_busy_time = 1.0  # How long it takes to establish a newly entangled pair
swapper_wait_time = 0.1    # How long to wait if all qubits are unavailable for swapping
swapper_busy_time = 0.15   # How long it takes to swap two qubits
purifier_wait_time = 0.15  # How long to wait if there are no pairs to be purified
purifier_busy_time = 0.2   # How long the purification circuit takes to execute

sim, network = simulation_setup(sizes, T2)

noisy_pair = noisy_pair_func(F)
for (;src, dst) in edges(network)
    @process entangler(sim, network, src, dst, noisy_pair, entangler_wait_time, entangler_busy_time)
end
for node in vertices(network)
    @process swapper(sim, network, node, swapper_wait_time, swapper_busy_time)
end
for nodea in vertices(network)
    for nodeb in vertices(network)
        if nodeb>nodea
            @process purifier(sim, network, nodea, nodeb, purifier_wait_time, purifier_busy_time)
        end
    end
end

# set up a plot and save a handle to the plot observable
fig = Figure(resolution=(400,400))
_,ax,_,obs = registernetplot_axis(fig[1,1],network)
display(fig)

# record the simulation progress
step_ts = range(0, 30, step=0.1)
record(fig, "firstgenrepeater-05.purifier.mp4", step_ts, framerate=10) do t
    run(sim, t)
    notify(obs)
    ax.title = "t=$(t)"
end
