include("clifford_setup.jl")

using GLMakie # For plotting
GLMakie.activate!()

##
# Demo visualizations of the performance of the network
##
sizes = [2,3,4,3,2]        # Number of qubits in each register
T2 = 100.0                 # T2 dephasing time of all qubits
F = 0.97                   # Fidelity of the raw Bell pairs
entangler_wait_time = 0.1  # How long to wait if all qubits are busy before retring entangling
entangler_busy_time = 1.0  # How long it takes to establish a newly entangled pair
swapper_wait_time = 0.1    # How long to wait if all qubits are unavailable for swapping
swapper_busy_time = 0.15   # How long it takes to swap two qubits
purifier_wait_time = 0.15  # How long to wait if there are no pairs to be purified
purifier_busy_time = 0.2   # How long the purification circuit takes to execute

sim, network = simulation_setup(sizes, T2; representation = CliffordRepr)

noisy_pair = stab_noisy_pair_func(F)
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

fig = Figure(resolution=(800,400))
subfig_rg, ax_rg, p_rn = registernetplot_axis(fig[1,1],network)

ts = Observable(Float64[0])
fidXX = Observable(Float64[0])
fidZZ = Observable(Float64[0])
ax_fid = Axis(fig[1,2][1,1], xlabel="time", ylabel="Entanglement Stabilizer\nExpectation")
lXX = stairs!(ax_fid,ts,fidXX,label="XX")
lZZ = stairs!(ax_fid,ts,fidZZ,label="ZZ")
xlims!(0, nothing)
ylims!(-.05, 1.05)
Legend(fig[1,2][2,1],[lXX,lZZ],["XX","ZZ"],
            orientation = :horizontal, tellwidth = false, tellheight = true)

display(fig)

registers = [network[node] for node in vertices(network)]
last = length(registers)

step_ts = range(0, 100, step=0.1)
record(fig, "firstgenrepeater-08.clifford.mp4", step_ts, framerate=10) do t
    run(sim, t)

    fXX = real(observable(registers[[1,last]], [2,2], XX, 0.0; time=t))
    fZZ = real(observable(registers[[1,last]], [2,2], ZZ, 0.0; time=t))
    push!(fidXX[],fXX)
    push!(fidZZ[],fZZ)
    push!(ts[],t)

    ax_rg.title = "t=$(t)"
    notify(p_rn[1])
    notify(ts)
    xlims!(ax_fid, 0, t+0.5)
end
