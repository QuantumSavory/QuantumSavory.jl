using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo
using InteractiveUtils
using REPL

qualified_name(T) = string(parentmodule(T), ".", nameof(T))

@testset "InteractiveUtils catalogs" begin
    @testset "public API" begin
        for name in (
            :available_slot_types,
            :available_background_types,
            :constructor_metadata,
        )
            @test Base.ispublic(QuantumSavory, name)
            @test !Base.isexported(QuantumSavory, name)
        end
        for name in (
            :AbstractProtocol,
            :available_protocol_types,
            :protocol_catalog_metadata,
            :permits_virtual_edge,
        )
            @test Base.ispublic(ProtocolZoo, name)
            @test !Base.isexported(ProtocolZoo, name)
        end
    end

    @testset "slot and background descriptors" begin
        slots = QuantumSavory.available_slot_types()
        @test propertynames.(slots) == fill((:type, :doc), 2)
        @test getproperty.(slots, :type) == [Qubit, Qumode]
        @test issorted(qualified_name.(getproperty.(slots, :type)))
        @test all(entry -> !isnothing(entry.doc), slots)
        @test all(isempty, QuantumSavory.constructor_metadata.(getproperty.(slots, :type)))

        backgrounds = QuantumSavory.available_background_types()
        expected_backgrounds = [
            AmplitudeDamping,
            Depolarization,
            PauliNoise,
            T1Decay,
            T1T2Noise,
            T2Dephasing,
        ]
        @test propertynames.(backgrounds) == fill((:type, :doc), length(backgrounds))
        @test getproperty.(backgrounds, :type) == expected_backgrounds
        @test issorted(qualified_name.(getproperty.(backgrounds, :type)))
        @test all(entry -> !isnothing(entry.doc), backgrounds)

        expected_fields = Dict(
            AmplitudeDamping => [:τ],
            Depolarization => [:τ],
            PauliNoise => [:τˣ, :τʸ, :τᶻ],
            T1Decay => [:t1],
            T1T2Noise => [:t1, :t2],
            T2Dephasing => [:t2],
        )
        for background in expected_backgrounds
            metadata = QuantumSavory.constructor_metadata(background)
            @test propertynames.(metadata) == fill((:field, :type, :doc), length(metadata))
            @test getproperty.(metadata, :field) == expected_fields[background]
            @test all(field -> field.type === Float64, metadata)
            @test all(field -> field.doc isa AbstractString && !isempty(field.doc), metadata)
        end
    end

    @testset "protocol descriptors" begin
        protocols = ProtocolZoo.available_protocol_types()
        expected_protocols = [
            CutoffProt,
            EntanglementConsumer,
            EntanglementTracker,
            EntanglerProt,
            EndNodeController,
            LinkController,
            NetworkNodeController,
            SwapperProt,
            SimpleSwitchDiscreteProt,
        ]
        @test getproperty.(protocols, :type) == expected_protocols
        @test issorted(qualified_name.(getproperty.(protocols, :type)))
        @test all(
            entry -> propertynames(entry) == (
                :type,
                :doc,
                :nodeargs,
                :attachment,
                :attachment_fields,
                :parameters,
                :permits_virtual_edge,
            ),
            protocols,
        )

        expected_attachments = Dict(
            CutoffProt => (:node, (node=:node,)),
            EntanglementConsumer => (:edge, (node_a=:nodeA, node_b=:nodeB)),
            EntanglementTracker => (:node, (node=:node,)),
            EntanglerProt => (:edge, (node_a=:nodeA, node_b=:nodeB)),
            EndNodeController => (:node, (node=:node,)),
            LinkController => (:edge, (node_a=:nodeA, node_b=:nodeB)),
            NetworkNodeController => (:node, (node=:node,)),
            SwapperProt => (:node, (node=:node,)),
            SimpleSwitchDiscreteProt => (:node, (node=:switchnode,)),
        )
        expected_parameter_fields = Dict(
            CutoffProt => [:period, :retention_time, :announce, :max_delete_per_slot],
            EntanglementConsumer => [:period, :tag],
            EntanglementTracker => [],
            EntanglerProt => [
                :pairstate,
                :success_prob,
                :attempt_time,
                :local_busy_time_pre,
                :local_busy_time_post,
                :retry_lock_time,
                :rounds,
                :attempts,
                :chooseslotA,
                :chooseslotB,
                :randomize,
                :uselock,
                :margin,
                :hardmargin,
                :tag,
            ],
            EndNodeController => [],
            LinkController => [],
            NetworkNodeController => [],
            SwapperProt => [
                :chooseslots,
                :nodeL,
                :nodeH,
                :chooseL,
                :chooseH,
                :local_busy_time,
                :retry_lock_time,
                :rounds,
                :agelimit,
                :max_history_per_slot,
            ],
            SimpleSwitchDiscreteProt => [
                :clientnodes,
                :success_probs,
                :ticktock,
                :rounds,
                :assignment_algorithm,
            ],
        )

        for entry in protocols
            attachment, attachment_fields = expected_attachments[entry.type]
            @test entry.attachment === attachment
            @test entry.attachment_fields == attachment_fields
            @test entry.nodeargs == length(attachment_fields)
            @test getproperty.(entry.parameters, :field) ==
                expected_parameter_fields[entry.type]
            @test all(
                parameter -> propertynames(parameter) == (:field, :type, :doc, :required),
                entry.parameters,
            )
            @test all(parameter -> parameter.doc isa AbstractString, entry.parameters)
            @test all(parameter -> !startswith(String(parameter.field), "_"), entry.parameters)
            @test all(
                parameter -> parameter.type == fieldtype(
                    entry.type,
                    findfirst(==(parameter.field), fieldnames(entry.type)),
                ),
                entry.parameters,
            )
            topology_fields = Tuple(values(entry.attachment_fields))
            @test all(
                parameter -> parameter.field ∉ (:sim, :net) &&
                    parameter.field ∉ topology_fields,
                entry.parameters,
            )
        end

        required = Dict(
            entry.type => getproperty.(
                filter(parameter -> parameter.required, entry.parameters),
                :field,
            )
            for entry in protocols
        )
        @test required[SimpleSwitchDiscreteProt] == [:clientnodes, :success_probs]
        @test all(
            isempty(required[type])
            for type in setdiff(expected_protocols, [SimpleSwitchDiscreteProt])
        )

        virtual_edges = Dict(
            entry.type => entry.permits_virtual_edge
            for entry in protocols
        )
        @test virtual_edges[EntanglementConsumer]
        @test all(
            !virtual_edges[type]
            for type in setdiff(expected_protocols, [EntanglementConsumer])
        )

        @test :_log ∉ getproperty.(
            only(filter(entry -> entry.type === EntanglementConsumer, protocols)).parameters,
            :field,
        )
        @test :_backlog ∉ getproperty.(
            only(filter(entry -> entry.type === SimpleSwitchDiscreteProt, protocols)).parameters,
            :field,
        )

        mbqc_types = (
            ProtocolZoo.MBQCEntanglementDistillation.GraphStateConstructor,
            ProtocolZoo.MBQCEntanglementDistillation.GraphToResource,
            ProtocolZoo.MBQCEntanglementDistillation.PurifierBellMeasurements,
            ProtocolZoo.MBQCEntanglementDistillation.MBQCPurificationTracker,
        )
        @test all(type -> type ∉ expected_protocols, mbqc_types)
        @test all(type -> !applicable(ProtocolZoo.protocol_catalog_metadata, type), mbqc_types)
    end

    @testset "isolated external package fixture" begin
        fixture = joinpath(@__DIR__, "fixtures", "open_world_metadata_fixture.jl")
        project = dirname(Base.active_project())
        command = `$(Base.julia_cmd()) --startup-file=no --project=$(project) $(fixture)`
        output = IOBuffer()
        process = run(pipeline(ignorestatus(command); stdout=output, stderr=output))
        result = String(take!(output))
        if !success(process)
            @error "The isolated metadata fixture failed" output=result
        end
        @test success(process)
    end
end
