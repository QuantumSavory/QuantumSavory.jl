using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo
using InteractiveUtils
using REPL
using Graphs

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

    for protocol in protocols
        @test all(parameter -> !isnothing(parameter.doc), protocol.parameters)
    end

    @testset "catalog fields construct SimpleSwitchDiscreteProt" begin
        entry = only(filter(protocols) do protocol
            protocol.type === SimpleSwitchDiscreteProt
        end)
        required = Set(parameter.field for parameter in entry.parameters if parameter.required)
        @test required == Set((:clientnodes, :success_probs))
        @test :_backlog ∉ (parameter.field for parameter in entry.parameters)

        net = RegisterNet(star_graph(2), [Register(1), Register(1)])
        kwargs = Dict{Symbol,Any}(
            :sim => get_time_tracker(net),
            :net => net,
            only(values(entry.attachment_fields)) => 1,
            :clientnodes => [2],
            :success_probs => [1.0],
        )
        switch = entry.type(; kwargs...)

        @test switch.switchnode == 1
        @test switch._backlog[1, 1] == 0
    end
end
