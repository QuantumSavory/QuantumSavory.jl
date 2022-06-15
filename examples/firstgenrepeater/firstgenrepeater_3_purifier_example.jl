include("firstgenrepeater_setup.jl")

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

sim, mgraph = simulation_setup(sizes, T2)

for (;src, dst) in edges(mgraph)
    @process entangler(sim, mgraph, src, dst, F, entangler_wait_time, entangler_busy_time)
end
for node in vertices(mgraph)
    @process swapper(sim, mgraph, node, swapper_wait_time, swapper_busy_time)
end
for nodea in vertices(mgraph)
    for nodeb in vertices(mgraph)
        if nodeb>nodea
            @process purifier(sim, mgraph, nodea, nodeb, purifier_wait_time, purifier_busy_time)
        end
    end
end

# set up a plot
fig = Figure(resolution=(400,400))
registers = [get_prop(mgraph, node, :register) for node in vertices(mgraph)]
registersobs = Observable(registers)
subfig_rg, ax_rg, p_rg = registersgraph_axis(fig[1,1],registersobs;graph=mgraph)
display(fig)

# record the simulation progress
step_ts = range(0, 30, step=0.1)
record(fig, "firstgenrepeater-05.purifier.mp4", step_ts, framerate=10) do t
    run(sim, t)
    notify(registersobs)
    ax_rg.title = "t=$(t)"
end
