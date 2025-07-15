using Revise # for interactive work on docs
push!(LOAD_PATH,"../src/")

using Documenter
using DocumenterCitations, DocumenterMermaid
using QuantumSavory
using QuantumSavory.StatesZoo, QuantumSavory.ProtocolZoo, QuantumSavory.CircuitZoo
using QuantumInterface

DocMeta.setdocmeta!(QuantumSavory, :DocTestSetup, :(using QuantumSavory, QuantumSavory.StatesZoo, QuantumSavory.ProtocolZoo, QuantumSavory.CircuitZoo); recursive=true)

function main()
    bib = CitationBibliography(joinpath(@__DIR__,"src/references.bib"), style=:authoryear)
    makedocs(
    plugins = [bib],
    doctest = false,
    clean = true,
    warnonly = [:missing_docs],
    sitename = "QuantumSavory.jl",
    format = Documenter.HTML(
        assets=["assets/custom.css"]
    ),
    modules = [QuantumSavory, QuantumSavory.StatesZoo, QuantumSavory.ProtocolZoo, QuantumSavory.CircuitZoo, QuantumInterface],
    authors = "Stefan Krastanov",
    pages = [
    "QuantumSavory.jl" => "index.md",
    "Getting Started Manual" => "manual.md",
    "Explanations" => [
        "explanations.md",
        "Register Interface" => "register_interface.md",
        "Properties" => "properties.md",
        "Background Noise" => "backgrounds.md",
        "Symbolic Expressions" => "symbolics.md",
        "Tagging and Querying" => "tag_query.md",
        "Backend Simulators" => "backendsimulator.md",
        "Discrete Event Simulator" => "discreteeventsimulator.md",
        "Visualizations" => "visualizations.md",
    ],
    "How-To Guides" => [
        "howto.md",
        "1st-gen Repeater - low level implementation" => "howto/firstgenrepeater/firstgenrepeater.md",
        "1st-gen Repeater - Clifford formalism" => "howto/firstgenrepeater/firstgenrepeater-clifford.md",
        "1st-gen Repeater - simpler implementation" => "howto/firstgenrepeater_v2/firstgenrepeater_v2.md",
        "Congestion on a Repeater Chain" => "howto/congestionchain/congestionchain.md",
        "Cluster States in Atomic Memories" => "howto/colorcentermodularcluster/colorcentermodularcluster.md",
        "Entanglement Switch" => "howto/simpleswitch/simpleswitch.md",
    ],
    "Tutorials" => [
        "tutorial.md",
        "Gate Duration" => "tutorial/noninstantgate.md",
        "State Explorer" => "tutorial/state_explorer.md",
        #"Message queues" => "tutorial/message_queues.md", TODO
        #"Depolarization and Pauli Noise" => "tutorial/depolarization_and_pauli.md", TODO
    ],
    "References" => [
        "references.md",
        "API" => "API.md",
        "CircuitZoo API" => "API_CircuitZoo.md",
        "StatesZoo API" => "API_StatesZoo.md",
        "ProtocolZoo API" => "API_ProtocolZoo.md",
        "Bibliography" => "bibliography.md",
    ],
    ]
    )
    deploydocs(
        repo = "github.com/QuantumSavory/QuantumSavory.jl.git"
    )
end

main()
