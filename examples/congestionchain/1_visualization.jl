include("setup.jl")

using GLMakie # For plotting
GLMakie.activate!(inline=false)

##
# Demo visualizations of the performance of the network
##
len = 5                    # Number of registers in the chain
regsize = 2                # Number of qubits in each register
T2 = 100.0                 # T2 dephasing time of all qubits
F = 0.97                   # Fidelity of the raw Bell pairs
entangler_wait_time = 0.1  # How long to wait if all qubits are busy before retring entangling
entangler_busy_λ = 0.5     # How long it takes to establish a newly entangled pair (Exponential distribution parameter)
swapper_wait_time = 0.1    # How long to wait if all qubits are unavailable for swapping
swapper_busy_time = 0.55   # How long it takes to swap two qubits
consume_wait_time = 0.1    # How long to wait if there are no qubits ready for consumption

sim, network = simulation_setup(len, regsize, T2)

noisy_pair = noisy_pair_func(F)
for (;src, dst) in edges(network)
    @process entangler(sim, network, src, dst, noisy_pair, entangler_wait_time, entangler_busy_λ)
end

for node in vertices(network)
    @process swapper(sim, network, node, swapper_wait_time, swapper_busy_time)
end

ts = Observable(Float64[])
fidXX = Observable(Float64[])
fidZZ = Observable(Float64[])
@process consumer(sim, network, 1, len, consume_wait_time,ts,fidXX,fidZZ)

fig = Figure(size=(800,400))
_,ax,_,obs = registernetplot_axis(fig[1,1],network)

ax_fidXX = Axis(fig[1,2][1,1], xlabel="", ylabel="XX Stabilizer\nExpectation")
ax_fidZZ = Axis(fig[1,2][2,1], xlabel="time", ylabel="ZZ Stabilizer\nExpectation")
c1 = Makie.wong_colors()[1]
c2 = Makie.wong_colors()[2]
scatter!(ax_fidXX,ts,fidXX,label="XX",color=(c1,0.1))
scatter!(ax_fidZZ,ts,fidZZ,label="ZZ",color=(c2,0.1))

display(fig)

step_ts = range(0, 1000, step=0.1)

record(fig, "congestionchain.mp4", step_ts; framerate=50, visible=true) do t
    run(sim, t)
    ax.title = "t=$(t)"
    notify(obs)
    notify(ts)
    autolimits!(ax_fidXX)
    autolimits!(ax_fidZZ)
end

##
