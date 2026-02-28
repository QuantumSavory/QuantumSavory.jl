using GLMakie

include("setup.jl")

sim, net, graph, consumer, params... = prepare_simulation()

fig = Figure(;size=(1200, 1100))

# Ring layout using Shell from NetworkLayout (places nodes in a circle)
layout = Shell()(graph)
_, ax, _, obs = registernetplot_axis(fig[1:2,1], net; registercoords=layout)

# Performance logging
entlog = Observable(consumer._log)
ts = @lift [e.t for e in $entlog]
tzzs = @lift [Point2f(e.t, e.obs1) for e in $entlog]
txxs = @lift [Point2f(e.t, e.obs2) for e in $entlog]
Δts = @lift length($ts) > 1 ? $ts[2:end] .- $ts[1:end-1] : [0.0]

# Entanglement fidelity plot
entlogaxis = Axis(fig[1,2], xlabel="Time", ylabel="⟨XX⟩", title="Entanglement Fidelity (⟨XX⟩)")
ylims!(entlogaxis, (-1.04, 1.04))
stem!(entlogaxis, txxs)

# Delivery time histogram
histaxis = Axis(fig[2,2], xlabel="ΔTime", title="Time Between Successful Deliveries")
hist!(histaxis, Δts)

# Running average fidelity
avg_fids = @lift cumsum([e.obs2 for e in $entlog]) ./ cumsum(ones(length($entlog)))
fid_info = @lift [Point2f(t, f) for (t, f) in zip($ts, $avg_fids)]
fid_axis = Axis(fig[3,1], xlabel="Time", ylabel="Avg. ⟨XX⟩",
    title="Running Average Fidelity")
lines!(fid_axis, fid_info)

# Throughput (pairs per unit time)
num_epr = @lift cumsum(ones(length($entlog))) ./ ($ts)
num_epr_info = @lift [Point2f(t, n) for (t, n) in zip($ts, $num_epr)]
num_epr_axis = Axis(fig[3,2], xlabel="Time",
    title="Avg. Entangled Pairs Delivered (Alice↔Bob)")
lines!(num_epr_axis, num_epr_info)

# Interactive sliders
sg = SliderGrid(
    fig[4,:],
    (label="Entanglement success probability",
        range=0.001:0.05:1.0, format="{:.3f}", startvalue=0.005),
    (label="Swap busy time",
        range=0.001:0.5:10.0, format="{:.3f}", startvalue=0.001),
    (label="Swap retry wait time",
        range=0.1:0.05:1.0, format="{:.2f}", startvalue=0.1),
    (label="Qubit retention time",
        range=0.1:0.1:10.0, format="{:.2f}", startvalue=5.0),
    (label="Agelimit buffer time",
        range=0.1:0.5:10.0, format="{:.2f}", startvalue=0.5),
    (label="Consumer query period",
        range=0.001:0.05:1.0, format="{:.3f}", startvalue=0.1),
    (label="Cutoff query period",
        range=0.001:0.05:1.0, format="{:.3f}", startvalue=0.1),
    width=600,
    tellheight=false)

for (param, slider) in zip(params, sg.sliders)
    on(slider.value) do val
        param[] = val
    end
end

display(fig)

step_ts = range(0, 50, step=0.1)
record(fig, "ring_sim.mp4", step_ts; framerate=10, visible=true) do t
    run(sim, t)
    notify.((obs, entlog))
    notify.(params)
    ylims!(entlogaxis, (-1.04, 1.04))
    xlims!(entlogaxis, max(0, t-50), 1+t)
    ylims!(fid_axis, (0, 1.04))
    xlims!(fid_axis, max(0, t-50), 1+t)
    autolimits!(histaxis)
    ylims!(num_epr_axis, (0, 4))
    xlims!(num_epr_axis, max(0, t-50), 1+t)
end
