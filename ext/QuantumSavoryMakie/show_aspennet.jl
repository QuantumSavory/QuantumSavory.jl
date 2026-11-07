using QuantumSavory.ProtocolZoo: AspenNet

function protshowimage(layout, p::AspenNet.Source)
    axis = Axis(layout[1, 1]; xlabel="Time within buffer", ylabel="Photon availability",
        title="Release every $(p.tick_duration * p.repetitions); send probability $(p.reflectivity)")
    attempts = 0:p.repetitions
    lines!(axis, attempts .* p.tick_duration,
        1 .- (1 - p.heralding_probability) .^ attempts)
    ylims!(axis, 0, 1)
    return axis
end

function protshowimage(layout, p::Union{AspenNet.LocalMeasurement,AspenNet.Hub}; history=Observable(p._log))
    hub = p isa AspenNet.Hub
    axis = Axis(layout[1, 1]; xlabel="Simulation time", ylabel=hub ? "Hub result" : "Local detector click",
        yticks=hub ? ([0, 1], ["Failure", "Success"]) : [0, 1])
    points = lift(history) do entries
        Point2f[Point2f(entry.t, getproperty(entry, hub ? :success : :number)) for entry in entries]
    end
    scatter!(axis, points)
    text!(axis, 0.5, 0.5; text="No results", space=:relative, align=(:center, :center),
        visible=lift(isempty, history))
    ylims!(axis, -0.2, 1.2)
    return axis
end
