using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo
using InteractiveUtils
using REPL

@testset "InteractiveUtils catalogs" begin
    slots = QuantumSavory.available_slot_types()
    backgrounds = QuantumSavory.available_background_types()
    protocols = ProtocolZoo.available_protocol_types()

    @test !isempty(slots)
    @test !isempty(backgrounds)
    @test !isempty(protocols)

    for entry in (slots..., backgrounds..., protocols...)
        @test !isnothing(entry.doc)
    end

    for entry in (backgrounds..., protocols...)
        @test !isempty(QuantumSavory.constructor_metadata(entry.type))
    end

    state_types = (
        QuantumSavory.StatesZoo.BarrettKokBellPair,
        QuantumSavory.StatesZoo.BarrettKokBellPairW,
        QuantumSavory.StatesZoo.DepolarizedBellPair,
        QuantumSavory.StatesZoo.Genqo.GenqoMultiplexedCascadedBellPairW,
        QuantumSavory.StatesZoo.Genqo.GenqoUnheraldedSPDCBellPairW,
    )
    for state_type in state_types
        metadata = QuantumSavory.constructor_metadata(state_type)
        documented_fields = Set(entry.field for entry in metadata if !isempty(string(entry.doc)))
        @test all(in(documented_fields), QuantumSavory.StatesZoo.stateparameters(state_type))
    end

    for protocol in protocols
        @test all(parameter -> !isnothing(parameter.doc), protocol.parameters)
    end
end
