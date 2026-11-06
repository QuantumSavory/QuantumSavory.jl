using PrettyTables: pretty_table

Base.show(io::IO, p::Source) = print(io,
    "AspenNet.Source($(p.node) → $(p.hub), $(length(p.memories)) memories, ",
    "period=$(p.tick_duration * p.repetitions))")
Base.show(io::IO, p::LocalMeasurement) = print(io,
    "AspenNet.LocalMeasurement(node=$(p.node), $(length(p._log)) measurements)")
Base.show(io::IO, p::Hub) = print(io,
    "AspenNet.Hub(node=$(p.node), $(count(e -> e.success, p._log))/$(length(p._log)) successes)")

function Base.show(io::IO, ::MIME"text/plain", p::Source)
    show(io, p)
    print(io, "\nTick duration: $(p.tick_duration); repetitions: $(p.repetitions)",
        "\nHeralding probability: $(p.heralding_probability)",
        "\nBuffered availability: $(1 - (1 - p.heralding_probability)^p.repetitions)",
        "\nRemote photon probability when available: $(p.reflectivity)")
end

function Base.show(io::IO, ::MIME"text/plain", p::Union{LocalMeasurement,Hub})
    show(io, p)
    println(io)
    pretty_table(io, p._log; maximum_number_of_rows=25)
end

function Base.show(io::IO, ::MIME"text/html", p::Union{Source,LocalMeasurement,Hub})
    summary = QuantumSavory._html_escape_text(sprint(show, p))
    print(io, "<div class=\"quantumsavory_show quantumsavory_protocol quantumsavory_protocol_aspennet\"><h1>", summary, "</h1>")
    if p isa Source
        print(io, "<pre>", QuantumSavory._html_escape_text(sprint(show, MIME"text/plain"(), p)), "</pre>")
    else
        pretty_table(io, p._log; backend=:html, maximum_number_of_rows=25)
    end
    print(io, "</div>")
end
