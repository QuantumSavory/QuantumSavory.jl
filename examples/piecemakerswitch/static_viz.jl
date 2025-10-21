include("setup.jl")
using GLMakie
GLMakie.activate!(inline=false)


logging = Point2f[] # for plotting
mem_depolar_prob = 0.1 # memory depolarization probability
decoherence_rate = - log(1 - mem_depolar_prob) # decoherence rates
noise_model = Depolarization(1/decoherence_rate) # noise model applied to the memory qubits
rounds = 100 # number of rounds to run

sim = prepare_sim(
    5, QuantumOpticsRepr(), noise_model, 0.5, 42, rounds
)

timed = @elapsed run(sim)
println("Simulation finished in $(timed) seconds")
@info logging

function plot_fidelity(logging::Vector{Point2f})
    fig = Figure(resolution = (800, 450))
    ax  = Axis(fig[1, 1], xlabel = "Δt (simulation time)", ylabel = "Fidelity to GHZₙ",
               title = "Entanglement fidelity over time")
    scatter!(ax, logging, markersize = 8)
    ylims!(ax, 0, 1)
    fig
end

fig = plot_fidelity(logging)
display(fig)
wait() # keeps REPL open until the figure is closed

# optional: save it
# save("examples/piecemakerswitch/fidelity.png", fig)