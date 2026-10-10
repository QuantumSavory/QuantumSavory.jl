using GLMakie

include("setup.jl")

testrun = get(ENV, "QS_TESTRUN", "false") == "true"

# Live-tunable parameters, readable by the protocol processes each round
intercept_prob = Observable(0.5)
period = Observable(1.0)

sim, net, stats = prepare_simulation(intercept_prob=intercept_prob, period=period, rounds=10^9, seed=42)

fig = Figure(size=(1400, 900))

# Network layout of the Alice-Eve-Bob chain
_, _, _, netobs = registernetplot_axis(fig[1, 1], net)

# Running QBER over simulation time
# Use one observable of complete points per curve: changing separate x/y
# vectors synchronously can transiently give Makie mismatched lengths.
qber_points = Observable(Point2f[])
ax_qber = Axis(fig[1, 2], xlabel="time", ylabel="running QBER",
    title="BB84 QBER over time")
lines!(ax_qber, qber_points)
ylims!(ax_qber, 0, 0.5)

# Sifted key length over simulation time
key_points = Observable(Point2f[])
ax_key = Axis(fig[2, 2], xlabel="time", ylabel="sifted key length")
stairs!(ax_key, key_points)

# Sliders controlling the eavesdropper and the source rate
sliderfig = fig[3, 1]
Label(sliderfig[1, 1], "Eve intercept probability:")
s_p = Slider(sliderfig[1, 2], range=0:0.05:1, startvalue=0.5)
on(s_p.value) do val
    intercept_prob[] = val
end
Label(sliderfig[2, 1], "round period:")
s_t = Slider(sliderfig[2, 2], range=0.1:0.1:3.0, startvalue=1.0)
on(s_t.value) do val
    period[] = val
end

if !testrun
    display(fig)
end

# Run the simulation while updating the plots; bounded so the script terminates
T = testrun ? 100.0 : 1000.0
function refresh_bb84_plots!()
    qber_points[] = Point2f.(stats.times, stats.qber_over_time)
    key_points[] = Point2f.(stats.times, stats.sifted_over_time)
    xlims!(ax_qber, 0, max(1.0, now(sim)))
    autolimits!(ax_key)
    notify(netobs)
    return nothing
end

for t in 0.0:1.0:T
    run(sim, t)
    refresh_bb84_plots!()
    # Yield to GLMakie's render/input tasks so sliders can actually be used
    # during a normal run. Headless regression tests do not need wall-clock pacing.
    if !testrun
        sleep(1 / 60)
    end
end
