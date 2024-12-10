using Revise # for interactive work on docs
push!(LOAD_PATH,"../src/")

using Documenter
using DocumenterCitations
using QuantumSavory
using QuantumSavory.ProtocolZoo # TODO is this the correct place to place this to ensure cross_references work

DocMeta.setdocmeta!(QuantumSavory, :DocTestSetup, :(using QuantumSavory); recursive=true)

function main()
    bib = CitationBibliography(joinpath(@__DIR__,"src/references.bib"), style=:authoryear)
    makedocs(
    plugins = [bib],
    doctest = false,
    clean = true,
    warnonly = [:missing_docs],
    sitename = "QuantumSavory.jl",
    format = Documenter.HTML(
        assets=["assets/init.js"]
    ),
    modules = [QuantumSavory],
    authors = "Stefan Krastanov",
    pages = [
    "QuantumSavory.jl" => "index.md",
    "Getting Started Manual" => "manual.md",
    "Explanations" => [
        "explanations.md",
        "Register Interface" => "register_interface.md",
        "Properties and Backgrounds" => "propbackgrounds.md",
        "Symbolic Expressions" => "symbolics.md",
        "Tagging and Querying" => "tag_query.md",
        "Backend Simulatiors" => "backendsimulator.md",
        "Discrete Event Simulator" => "discreteeventsimulator.md",
        "Visualizations" => "visualizations.md",
    ],
    "How-To Guides" => [
        "howto.md",
        "1st-gen Repeater" => "howto/firstgenrepeater/firstgenrepeater.md",
        "1st-gen Repeater (Clifford formalism)" => "howto/firstgenrepeater/firstgenrepeater-clifford.md",
        "Cluster States in Atomic Memories" => "howto/colorcentermodularcluster/colorcentermodularcluster.md",
    ],
    "Tutorials" => [
        "tutorial.md",
        "Gate duration" => "tutorial/noninstantgate.md",
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
