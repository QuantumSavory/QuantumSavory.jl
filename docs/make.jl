push!(LOAD_PATH,"../src/")

using Documenter
using DocumenterCitations
using QuantumSavory

DocMeta.setdocmeta!(QuantumSavory, :DocTestSetup, :(using QuantumSavory); recursive=true)

function main()
    bib = CitationBibliography(joinpath(@__DIR__,"src/references.bib"))
    makedocs(
    bib,
    doctest = false,
    clean = true,
    sitename = "QuantumSavory.jl",
    format = Documenter.HTML(
        assets=["assets/init.js"]
    ),
    modules = [QuantumSavory],
    authors = "Stefan Krastanov",
    pages = [
    "QuantumSavory.jl" => "index.md",
    "HowTos" => [
        "1st-gen Repeater" => "howto/firstgenrepeater/firstgenrepeater.md"
        "1st-gen Repeater (Clifford formalism)" => "howto/firstgenrepeater/firstgenrepeater-clifford.md"
    ],
    #"Manual" => "manual.md",
    "References" => [
        "Properties and Backgrounds" => "propbackgrounds.md",
        "Visualizations" => "visualizations.md",
        "API" => "API.md",
        "Dev Documentation" => [
            "Register Interface" => "register_interface.md",
        ],
        "Bibliography" => "bibliography.md"
    ],
    ]
    )

    deploydocs(
        repo = "github.com/Krastanov/QuantumSavory.jl.git"
    )
end

main()
