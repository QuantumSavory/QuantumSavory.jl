include("setup.jl")

using GLMakie
GLMakie.activate!(inline=false)

##
# Parameters
##

μ        = 3    # threshold line on the count plot
run_time = 0.5 # total simulation time to visualize

##
# Setup
##

net = build_sensor_net(S)
sim = get_time_tracker(net)

for i in 1:S
    @process EntanglementTracker(sim, net, i)()
end

for i in 1:S
    eprot = EntanglerProt(sim, net, i, S+1; pairstate=noisy_pair, chooseslotA=1, chooseslotB=i,
                          success_prob, attempt_time, attempts=-1, rounds=1)
    @process eprot()
end

# Sensors on a circle; hub coord offset down by (S-1)/2 so its multi-slot
# register (which grows upward one unit per slot) is visually centered.
star_coords = [Point2f(cos(2π*i/S), sin(2π*i/S)) .* (S+1) for i in 1:S]
push!(star_coords, Point2f(0, -(S-1)/2))

##
# Figure
##

fig = Figure(size=(900, 420))
Label(fig[0, 1:2], "GHZ sensor network: S=$S, p=$success_prob", fontsize=16)

_, ax_net, _, obs = registernetplot_axis(fig[1, 1], net; registercoords=star_coords)

ts    = Observable(Float64[0.0])
n_ent = Observable(Int[0])
ax_count = Axis(fig[1, 2], xlabel="time", ylabel="sensors entangled",
                title="Entangled sensor count")
ylims!(ax_count, -0.2, S + 0.2)
stairs!(ax_count, ts, n_ent, color=:steelblue)
hlines!(ax_count, [μ], color=:crimson, linestyle=:dash, label="μ = $μ")
axislegend(ax_count)

##
# Record — stops as soon as μ sensors are entangled
##

record(fig, "distributed_ghz_sensors.mp4", range(0, run_time, step=attempt_time); framerate=20, visible=true) do t
    run(sim, t)
    push!(ts[],    t)
    push!(n_ent[], length(entangled_sensors(net, S)))
    ax_net.title = "t=$(round(t, digits=4))"
    notify(obs)
    notify(ts)
    notify(n_ent)
    xlims!(ax_count, 0, t + attempt_time)
end
