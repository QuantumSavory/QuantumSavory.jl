using GLMakie

include("setup.jl")

sim, net, graph, consumer, params... = prepare_simulation()

fig = Figure(;size=(800, 600))

# the network part of the visualization
layout = SquareGrid(cols=:auto, dx=30.0, dy=-30.0)(graph) # provided by NetworkLayout, meant to simplify plotting of graphs in 2D
_, ax, _, obs = registernetplot_axis(fig[1:2,1], net;registercoords=layout)

# the performance log part of the visualization
entlog = Observable(consumer.log) # Observables are used by Makie to update the visualization in real-time in an automated reactive way
ts = @lift [e[1] for e in $entlog]  # TODO this needs a better interface, something less cluncky, maybe also a whole Makie recipe
tzzs = @lift [Point2f(e[1],e[2]) for e in $entlog]
txxs = @lift [Point2f(e[1],e[3]) for e in $entlog]
Δts = @lift length($ts)>1 ? $ts[2:end] .- $ts[1:end-1] : [0.0]
entlogaxis = Axis(fig[1,2], xlabel="Time", ylabel="Entanglement", title="Entanglement Successes")
ylims!(entlogaxis, (-1.04,1.04))
stem!(entlogaxis, tzzs)
histaxis = Axis(fig[2,2], xlabel="ΔTime", title="Histogram of Time to Successes")
hist!(histaxis, Δts)

#  sliders
sg = SliderGrid(
    fig[3,1],
    (label="Probability of success of Entanglement generation at each attempt",
        range=0.001:0.05:1.0, format="{:.2f}", startvalue=0.001),
    (label="Local busy time for swapper",
        range=0.001:0.5:10.0, format="{:.2f}", startvalue=0.001),
    (label="Wait time after failure to lock qubits for a swap",
        range=0.1:0.05:1.0, format="{:.2f}", startvalue=0.1),
    (label="Retention time for an unused qubit",
        range=0.1:0.1:10.0, format="{:.2f}", startvalue=5.0),
    (label="Time before a qubit's retention time runs out (for `agelimit`)",
        range=0.1:0.5:10.0, format="{:.2f}", startvalue=0.5),
    (label="Period of time between subsequent queries at the consumer",
        range=0.001:0.05:1.0, format="{:.2f}", startvalue=0.001),
    (label="Period of time between subsequent queries at the DecoherenceProtocol",
        range=0.001:0.05:1.0, format="{:.2f}", startvalue=0.001),

    width = 600,
    tellheight = false)

for (param, slider) in zip(params, sg.sliders)
    on(slider.value) do val
        param[] = val
    end
end


display(fig)

step_ts = range(0, 1000, step=0.1)
record(fig, "grid_sim6x6hv.mp4", step_ts; framerate=10, visible=true) do t
    run(sim, t)
    notify.((obs,entlog))
    notify.(params)
    ylims!(entlogaxis, (-1.04,1.04))
    xlims!(entlogaxis, max(0,t-50), 1+t)
    autolimits!(histaxis)
end