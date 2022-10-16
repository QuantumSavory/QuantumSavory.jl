include("setup.jl")

using GLMakie # For plotting
GLMakie.activate!()

##
# Demo the entangler on its own
##

sizes = [2,3,4,3,2]        # Number of qubits in each register
T2 = 10.0                  # T2 dephasing time of all qubits
F = 0.9                    # Fidelity of the raw Bell pairs
entangler_wait_time = 0.1  # How long to wait if all qubits are busy before retry
entangler_busy_time = 1.0  # How long it takes to establish a newly entangled pair

sim, network = simulation_setup(sizes, T2)

noisy_pair = noisy_pair_func(F)
for (;src, dst) in edges(network)
    @process entangler(sim, network, src, dst, noisy_pair, entangler_wait_time, entangler_busy_time)
end

# set up a plot
fig = Figure(resolution=(400,400))
subfig_rg, ax_rg, p_rn = registernetplot_axis(fig[1,1],network)
display(fig)

# record the simulation progress
step_ts = range(0, 4, step=0.1)
record(fig, "firstgenrepeater-02.entangler.mp4", step_ts, framerate=10) do t
    run(sim, t)
    notify(p_rn[1])
    ax_rg.title = "t=$(t)"
end
