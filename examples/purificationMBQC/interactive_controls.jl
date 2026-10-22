using GLMakie

include("interactive_setup.jl")

function trajectory_axis(position, history)
    axis = Axis(position, xlabel="Completion time (source attempt periods; log scale)",
        ylabel="Mean output Bell fidelity in one trajectory", xscale=log10,
        yticks=([-0.1, 0, 0.5, 1], ["Rejected", "0", "0.5", "1"]))
    ylims!(axis, -0.18, 1.08)
    xlims!(axis, 1, 10)

    accepted = lift(rs -> filter(r -> r.accepted, rs), history)
    rejected = lift(rs -> filter(r -> !r.accepted, rs), history)
    scatter!(axis, lift(rs -> [Point2f(r.duration, r.fidelity) for r in rs], accepted),
        color=(:steelblue, 0.65), markersize=12, label="Accepted",
        inspector_label=(plot, i, position) -> trial_description(accepted[][i]))
    scatter!(axis, lift(rs -> [Point2f(r.duration, -0.1) for r in rs], rejected),
        color=(:firebrick, 0.65), marker=:xcross, markersize=12, label="Rejected",
        inspector_label=(plot, i, position) -> trial_description(rejected[][i]))
    hlines!(axis, [0.5], color=(:gray, 0.5), linestyle=:dash, inspectable=false)
    axislegend(axis, position=:lb)
    axis
end

function source_controls(controls)
    Label(controls[1, 1], "Local links · Barrett–Kok", fontsize=19)
    p = default_source_parameters
    local_grid = SliderGrid(controls[2, 1],
        (label="Transmission A", range=0.1:0.01:1, startvalue=p.local_transmission_a),
        (label="Transmission B", range=0.1:0.01:1, startvalue=p.local_transmission_b),
        (label="Detection efficiency", range=0.1:0.01:1, startvalue=p.local_detection),
        (label="Dark-count probability", range=0:0.0001:0.01,
            startvalue=p.local_dark_counts, format="{:.4f}"),
        (label="Mode overlap |V| (real)", range=0:0.01:1, startvalue=p.local_visibility))
    Label(controls[3, 1], "Long-range links · Genqo cascaded source", fontsize=19)
    long_grid = SliderGrid(controls[4, 1],
        (label="BSM transmission", range=0.1:0.01:1, startvalue=p.long_bsm),
        (label="Detection efficiency", range=0.1:0.01:1, startvalue=p.long_detection),
        (label="Outcoupling transmission", range=0.1:0.01:1, startvalue=p.long_transmission),
        (label="Mean photons per mode N", range=0.001:0.001:0.2,
            startvalue=p.mean_photons, format="{:.3f}"))
    sliders = vcat(local_grid.sliders, long_grid.sliders)
    snapshot() = NamedTuple{keys(default_source_parameters)}(Tuple(s.value[] for s in sliders))

    (; sliders, snapshot)
end

function trial_description(result)
    outcome = result.accepted ? "Output fidelity: $(result.fidelity)" : "Rejected (no output pair)"
    settings = join(["$name = $value" for (name, value) in pairs(result.parameters)], "\n")
    "$outcome\nCompletion: $(result.duration) attempt periods\n$settings"
end
