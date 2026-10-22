using GLMakie

include("interactive_setup.jl")

const source_parameter_labels = (
    "Local transmission A", "Local transmission B", "Local detection efficiency",
    "Local dark-count probability", "Local mode overlap |V|",
    "Long-range BSM transmission", "Long-range detection efficiency",
    "Long-range outcoupling", "Mean photons per mode N",
    "Spin-capture noise p",
)

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

function source_controls(controls; selected=nothing)
    Label(controls[1, 1], "Local links · Barrett–Kok", fontsize=19)
    p = default_source_parameters
    local_grid = SliderGrid(controls[2, 1],
        (label="Transmission A", range=0.1:0.01:1, startvalue=p.local_transmission_a),
        (label="Transmission B", range=0.1:0.01:1, startvalue=p.local_transmission_b),
        (label="Detection efficiency", range=0.1:0.01:1, startvalue=p.local_detection),
        (label="Dark-count probability", range=0:0.0001:0.01,
            startvalue=p.local_dark_counts, format="{:.4f}"),
        (label="Mode overlap |V| (real)", range=0:0.01:1, startvalue=p.local_visibility))
    placement = local_grid.layout[6, 1:3] = GridLayout(tellwidth=false)
    Label(placement[1, 1], "Graph-edge Hadamard:", fontsize=15)
    Label(placement[1, 2], "Second", fontsize=15)
    hadamard_toggle = Toggle(placement[1, 3], active=p.hadamard_first)
    Label(placement[1, 4], "First", fontsize=15)
    Label(local_grid.layout[7, 1:3], lift(hadamard_toggle.active) do first
        first ? "First endpoint: overlap errors reach measured inputs." :
            "Second endpoint: overlap errors can reach outputs."
    end; fontsize=13)
    Label(controls[3, 1], "Long-range links · Genqo cascaded source", fontsize=19)
    long_grid = SliderGrid(controls[4, 1],
        (label="BSM transmission", range=0.1:0.01:1, startvalue=p.long_bsm),
        (label="Detection efficiency", range=0.1:0.01:1, startvalue=p.long_detection),
        (label="Outcoupling transmission", range=0.1:0.01:1, startvalue=p.long_transmission),
        (label="Mean photons per mode N", range=0.001:0.001:0.2,
            startvalue=p.mean_photons, format="{:.3f}"),
        (label="Spin-capture noise p", range=0:0.01:1, startvalue=p.spin_capture_noise))
    Label(long_grid.layout[6, 1:3], "After Genqo: ρ → (1 − p)ρ + p I₄/4", fontsize=13)
    sliders = vcat(local_grid.sliders, long_grid.sliders)
    snapshot() = merge(NamedTuple{keys(default_slider_parameters)}(Tuple(s.value[] for s in sliders)),
        (hadamard_first=hadamard_toggle.active[],))
    radios = Checkbox[]
    if !isnothing(selected)
        for (grid, offset) in ((local_grid, 0), (long_grid, length(local_grid.sliders)))
            for row in eachindex(grid.sliders)
                index = offset + row
                push!(radios, Checkbox(grid.layout[row, 4], roundness=1, checkmark=:circle,
                    checked=lift(i -> i == index, selected),
                    onchange=_ -> (selected[] = index; true)))
            end
        end
    end
    (; sliders, snapshot, radios, hadamard_toggle)
end

function trial_description(result)
    outcome = result.accepted ? "Output fidelity: $(result.fidelity)" : "Rejected (no output pair)"
    settings = join(["$name = $value" for (name, value) in pairs(result.parameters)], "\n")
    "$outcome\nCompletion: $(result.duration) attempt periods\n$settings"
end
