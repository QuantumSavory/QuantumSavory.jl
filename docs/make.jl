using Revise # for interactive work on docs
push!(LOAD_PATH,"../src/")

using Documenter
using DocumenterCitations, DocumenterMermaid
using AnythingLLMDocs
using CairoMakie
using QuantumSavory
using QuantumSavory.StatesZoo, QuantumSavory.ProtocolZoo, QuantumSavory.CircuitZoo
using QuantumSavory.StatesZoo.Genqo
using QuantumInterface
using QuantumSymbolics

DocMeta.setdocmeta!(QuantumSavory, :DocTestSetup, :(using QuantumSavory, QuantumSavory.StatesZoo, QuantumSavory.ProtocolZoo, QuantumSavory.CircuitZoo, QuantumSavory.StatesZoo.Genqo); recursive=true)

function state_visualization_qubit_state(repr)
    reg = Register(fill(Qubit(), 5), fill(repr, 5))
    initialize!(reg[1], X1)
    for i in 2:5
        initialize!(reg[i], Z1)
    end
    for i in 2:5
        apply!([reg[1], reg[i]], CNOT)
    end
    return QuantumSavory.stateof(reg[1])
end

function state_visualization_gabs_state()
    reg = Register(
        fill(Qumode(), 5),
        fill(GabsRepr(QuantumSavory.Gabs.QuadBlockBasis), 5),
    )
    for i in 1:5
        initialize!(reg[i], SqueezedState(0.15 * i))
        apply!(reg[i], DisplaceOp(0.1 * i - 0.05im * i))
    end
    for i in 1:4
        apply!([reg[i], reg[i + 1]], BeamSplitterOp(1 / 2))
    end
    return QuantumSavory.stateof(reg[1])
end

function generate_state_visualization_assets()
    CairoMakie.activate!()
    asset_dir = joinpath(@__DIR__, "src", "assets", "generated", "state_visualization")
    mkpath(asset_dir)
    examples = [
        ("quantumoptics_5subsystems.png", state_visualization_qubit_state(QuantumOpticsRepr())),
        ("gabs_5subsystems.png", state_visualization_gabs_state()),
        ("quantumclifford_5subsystems.png", state_visualization_qubit_state(CliffordRepr())),
    ]
    for (filename, stateref) in examples
        open(joinpath(asset_dir, filename), "w") do io
            show(io, MIME"image/png"(), stateref)
        end
    end
end

function main()
    generate_state_visualization_assets()

    doc_modules = [
        QuantumSavory,
        QuantumSavory.StatesZoo,
        QuantumSavory.ProtocolZoo,
        QuantumSavory.CircuitZoo,
        QuantumInterface,
        QuantumSymbolics,
    ]
    api_base="https://anythingllm.krastanov.org/api/v1"
    anythingllm_assets = integrate_anythingllm(
        "QuantumSavory",
        doc_modules,
        @__DIR__,
        api_base;
        repo = "github.com/QuantumSavory/QuantumSavory.jl.git",
        options = EmbedOptions(),
    )

    bib = CitationBibliography(joinpath(@__DIR__,"src/references.bib"), style=:authoryear)
    assets = Any["assets/custom.css"]
    append!(assets, anythingllm_assets)
    makedocs(
    plugins = [bib],
    doctest = false,
    clean = true,
    warnonly = [:missing_docs],
    sitename = "QuantumSavory.jl",
    format = Documenter.HTML(
        assets=assets
    ),
    modules = doc_modules,
    authors = "Stefan Krastanov",
    pages = [
    "QuantumSavory.jl" => "index.md",
    "Getting Started Manual" => "manual.md",
    "Explanations" => [
        "explanations.md",
        "Architecture and Mental Model" => "architecture.md",
        "Why QuantumSavory Exists" => "why_quantumsavory.md",
        "Restricted Formalisms and Efficient Simulation" =>
            "restricted_formalisms.md",
        "Choosing a Backend and Modeling Tradeoffs" => "modeling_tradeoffs.md",
        "Modeling Registers, Factorization, and Time" =>
            "modeling_registers_and_time.md",
        "Metadata and Protocol Composition" => "metadata_plane.md",
        "Classical Messaging and Buffers" => "classical_messaging.md",
        "Zoos as Composable Building Blocks" => "zoos_as_building_blocks.md",
        "Properties" => "properties.md",
        "Background Noise" => "backgrounds.md",
        "Symbolic Frontend" => "symbolic_frontend.md",
        "Discrete Event Simulator" => "discreteeventsimulator.md",
    ],
    "How-To Guides" => [
        "howto.md",
        "1st-gen Repeater - low level implementation" => "howto/firstgenrepeater/firstgenrepeater.md",
        "1st-gen Repeater - Clifford formalism" => "howto/firstgenrepeater/firstgenrepeater-clifford.md",
        "1st-gen Repeater - simpler implementation" => "howto/firstgenrepeater_v2/firstgenrepeater_v2.md",
        "Congestion on a Repeater Chain" => "howto/congestionchain/congestionchain.md",
        "Cluster States in Atomic Memories" => "howto/colorcentermodularcluster/colorcentermodularcluster.md",
        "Entanglement Switch" => "howto/simpleswitch/simpleswitch.md",
        "Cluster-State Walkthrough" => "howto/cluster_state_walkthrough.md",
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
        "Register Interface API" => "register_interface.md",
        "Backend Simulators" => "backendsimulator.md",
        "Tag and Query API" => "tag_query.md",
        "Symbolic Expressions Reference" => "symbolics.md",
        "API" => "API.md",
        "CircuitZoo API" => "API_CircuitZoo.md",
        "StatesZoo API" => "API_StatesZoo.md",
        "ProtocolZoo API" => "API_ProtocolZoo.md",
        "QuantumInterface API" => "API_Interface.md",
        "QuantumSymbolics API" => "API_Symbolics.md",
        "Visualizations" => "visualizations.md",
        "Quantum State Visualization" => "state_visualization.md",
        "Bibliography" => "bibliography.md",
    ],
    ]
    )
    deploydocs(
        repo = "github.com/QuantumSavory/QuantumSavory.jl.git",
        devbranch = "master",
        deploy_config = Documenter.Buildkite(),
        push_preview = true
    )
end

main()
