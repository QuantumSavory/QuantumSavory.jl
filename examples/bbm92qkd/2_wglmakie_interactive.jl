using WGLMakie
using NetworkLayout

include("setup.jl")

sim, net, graph, bbm92, params... = prepare_simulation()

fig = Figure(;size=(1200, 1100))

# Chain layout
layout = Spring()(graph)
_, ax, _, obs = registernetplot_axis(fig[1:2,1], net; registercoords=layout)

# BBM92 measurement log observable
bbm92log = Observable(bbm92._log)

ts = @lift [e.t for e in $bbm92log]

# QBER over time (running estimate)
running_qber = @lift begin
    log = $bbm92log
    qbers = Float64[]
    n_sifted = 0
    n_errors = 0
    for e in log
        if e.basisA == e.basisB
            n_sifted += 1
            if e.outcomeA != e.outcomeB
                n_errors += 1
            end
        end
        push!(qbers, n_sifted > 0 ? n_errors / n_sifted : 0.0)
    end
    [Point2f(log[i].t, qbers[i]) for i in eachindex(log)]
end
qber_axis = Axis(fig[1,2], xlabel="Time", ylabel="QBER",
    title="Running Quantum Bit Error Rate")
lines!(qber_axis, running_qber)

# Sifted key accumulation
sifted_count = @lift begin
    log = $bbm92log
    cum = Int[]
    n = 0
    for e in log
        if e.basisA == e.basisB
            n += 1
        end
        push!(cum, n)
    end
    [Point2f(log[i].t, cum[i]) for i in eachindex(log)]
end
key_axis = Axis(fig[2,2], xlabel="Time", ylabel="Sifted key bits",
    title="Cumulative Sifted Key Length")
lines!(key_axis, sifted_count)

# Key rate (sifted bits per unit time)
running_keyrate = @lift begin
    log = $bbm92log
    n_sifted = 0
    rates = Float64[]
    for (i, e) in enumerate(log)
        if e.basisA == e.basisB
            n_sifted += 1
        end
        push!(rates, e.t > 0 ? n_sifted / e.t : 0.0)
    end
    [Point2f(log[i].t, rates[i]) for i in eachindex(log)]
end
rate_axis = Axis(fig[3,1], xlabel="Time", ylabel="Key rate (bits/time)",
    title="Average Sifted Key Rate")
lines!(rate_axis, running_keyrate)

# Basis matching histogram
basis_stats = @lift begin
    log = $bbm92log
    n_match = count(e -> e.basisA == e.basisB, log)
    n_mismatch = length(log) - n_match
    [n_match, n_mismatch]
end
basis_axis = Axis(fig[3,2], xlabel="", ylabel="Count",
    title="Basis Matching", xticks=([1,2], ["Match\n(key bit)", "Mismatch\n(discarded)"]))
barplot!(basis_axis, [1, 2], basis_stats)

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
    (label="BBM92 query period",
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
for t in step_ts
    run(sim, t)
    notify.((obs, bbm92log))
    notify.(params)
    ylims!(qber_axis, (-0.04, 0.54))
    xlims!(qber_axis, max(0, t-50), 1+t)
    xlims!(key_axis, max(0, t-50), 1+t)
    autolimits!(key_axis)
    xlims!(rate_axis, max(0, t-50), 1+t)
    autolimits!(rate_axis)
    autolimits!(basis_axis)
    sleep(0.1)
end
