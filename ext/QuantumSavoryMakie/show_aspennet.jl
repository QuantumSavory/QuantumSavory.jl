using QuantumSavory.ProtocolZoo: AspenNet

function protshowimage(layout, p::AspenNet.Source)
    axis = Axis(layout[1, 1]; xlabel="Time within buffer", ylabel="Photon availability",
        title="Release every $(p.tick_duration * p.repetitions); send probability $(p.reflectivity)")
    attempts = 0:p.repetitions
    lines!(axis, attempts .* p.tick_duration,
        1 .- (1 - p.heralding_probability) .^ attempts)
    ylims!(axis, 0, 1)
end

function protshowimage(layout, p::Union{AspenNet.LocalMeasurement,AspenNet.Hub})
    hub = p isa AspenNet.Hub
    axis = Axis(layout[1, 1]; xlabel="Simulation time", ylabel=hub ? "Hub result" : "Local photon number",
        yticks=hub ? ([0, 1], ["Failure", "Success"]) : [0, 1])
    if isempty(p._log)
        text!(axis, 0.5, 0.5; text="No results", space=:relative, align=(:center, :center))
    else
        values = [Int(getproperty(entry, hub ? :success : :number)) for entry in p._log]
        scatter!(axis, [entry.t for entry in p._log], values)
    end
    ylims!(axis, -0.2, 1.2)
end
