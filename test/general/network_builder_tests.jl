using Test
using ConcurrentSim
using Graphs
using QuantumSavory
using QuantumSavory.ProtocolZoo

Base.@kwdef struct UncatalogedNodeProtocol <: ProtocolZoo.AbstractProtocol
    sim::Simulation
    net::RegisterNet
    node::Int
end

Base.@kwdef struct InvalidRequiredFieldProtocol <: ProtocolZoo.AbstractProtocol
    sim::Simulation
    net::RegisterNet
    node::Int
end

ProtocolZoo.protocol_catalog_metadata(::Type{InvalidRequiredFieldProtocol}) = (
    attachment=:node,
    attachment_fields=(node=:node,),
    required_fields=(:missing,),
)

@testset "Distance to propagation delay" begin
    @test dist_to_delay(0) == 0.0
    @test dist_to_delay(4.0e8) == 2.0
    @test dist_to_delay(3.0e8, 3.0e8) == 1.0

    distances = Dict(Edge(1, 2) => 1.0e8, Edge(2, 3) => 4.0e8)
    delays = dist_to_delay(distances)
    @test delays == Dict(Edge(1, 2) => 0.5, Edge(2, 3) => 2.0)
    @test delays !== distances
    @test dist_to_delay(distances, 1.0e8) ==
        Dict(Edge(1, 2) => 1.0, Edge(2, 3) => 4.0)

    for distance in (-1, -Inf, Inf, NaN)
        @test_throws DomainError dist_to_delay(distance)
    end
    for speed in (0, -1, -Inf, Inf, NaN)
        @test_throws DomainError dist_to_delay(1, speed)
        @test_throws DomainError dist_to_delay(Dict{Edge{Int},Float64}(), speed)
    end
end

@testset "Network builder validates topology and constructs channels" begin
    graph = path_graph(3)
    delays = Dict(Edge(1, 2) => 0.25, Edge(2, 3) => 0.75)
    (; sim, network) = network_builder(graph, delays, (2,))

    @test now(sim) == 0
    @test nv(network) == 3
    @test all(register -> length(register) == 2, network[:])
    @test all(register -> get_time_tracker(register) === sim, network[:])
    for edge in edges(graph)
        for (src, dst) in ((edge.src, edge.dst), (edge.dst, edge.src))
            @test channel(network, src => dst).delay == delays[edge]
            @test qchannel(network, src => dst).queue.delay == delays[edge]
        end
    end
    graph32 = SimpleGraph{Int32}(graph)
    delays32 = Dict(edge => big"0.5" for edge in edges(graph32))
    result32 = network_builder(graph32, delays32, (1,))
    @test result32.network.graph == graph
    @test channel(result32.network, 1 => 2).delay == 0.5

    @test_throws ArgumentError network_builder(SimpleGraph(0), Dict(), (1,))
    @test_throws ArgumentError network_builder(graph, Dict(Edge(1, 2) => 0.1), (1,))
    @test_throws ArgumentError network_builder(
        graph,
        Dict(Edge(1, 2) => 0.1, Edge(2, 3) => 0.1, Edge(1, 3) => 0.1),
        (1,),
    )
    for bad_delay in (-1.0, Inf, NaN, "slow", big(10)^1000)
        invalid_delays = Dict{Any,Any}(delays)
        invalid_delays[Edge(1, 2)] = bad_delay
        @test_throws ArgumentError network_builder(graph, invalid_delays, (1,))
    end
    @test_throws ArgumentError network_builder(graph, delays, (0,))
end

@testset "Network builder validates catalog protocol specifications" begin
    graph = path_graph(2)
    delays = Dict(only(edges(graph)) => 0.0)

    @test_throws ArgumentError network_builder(
        graph,
        delays,
        (1,);
        node_protocols=(Int => (;),),
    )
    @test_throws ArgumentError network_builder(
        graph,
        delays,
        (1,);
        node_protocols=(UncatalogedNodeProtocol => (;),),
    )
    @test_throws ArgumentError network_builder(
        graph,
        delays,
        (1,);
        node_protocols=(InvalidRequiredFieldProtocol => (;),),
    )
    @test_throws ArgumentError network_builder(
        graph,
        delays,
        (1,);
        node_protocols=(SimpleSwitchDiscreteProt => (;),),
    )
    @test_throws ArgumentError network_builder(
        graph,
        delays,
        (1,);
        node_protocols=(EntanglementTracker => (; unknown=true),),
    )
    @test_throws ArgumentError network_builder(
        graph,
        delays,
        (1,);
        node_protocols=(EndNodeController => (; _log=Dict()),),
    )
    for configured in ((; sim=Simulation()), (; net=nothing), (; node=1))
        @test_throws ArgumentError network_builder(
            graph,
            delays,
            (1,);
            node_protocols=(EntanglementTracker => configured,),
        )
    end
    @test_throws ArgumentError network_builder(
        graph,
        delays,
        (1,);
        node_protocols=(EntanglerProt => (;),),
    )
    @test_throws ArgumentError network_builder(
        graph,
        delays,
        (1,);
        link_protocols=(EntanglementTracker => (;),),
    )
    @test_throws ArgumentError network_builder(
        graph,
        delays,
        (1,);
        node_protocols=(EntanglementTracker => 1,),
    )
end

@testset "Network builder schedules real protocols without running them" begin
    graph = path_graph(3)
    delays = Dict(edge => 0.01 for edge in edges(graph))
    (; sim, network) = network_builder(
        graph,
        delays,
        (2,);
        node_protocols=(EntanglementTracker => (;),),
        link_protocols=(EntanglerProt => (;
            rounds=1,
            success_prob=1.0,
            attempt_time=0.1,
        ),),
    )

    @test now(sim) == 0
    @test all(!isassigned(network[node], slot) for node in vertices(graph) for slot in 1:2)

    run(sim, 1.0)
    for (; src, dst) in edges(graph)
        source = query(network[src], EntanglementCounterpart, dst, ❓, ❓)
        @test !isnothing(source)
        target = query(
            network[dst],
            EntanglementCounterpart,
            src,
            source.slot.idx,
            source.tag[4],
        )
        @test !isnothing(target)
        @test observable((source.slot, target.slot), Z ⊗ Z) ≈ 1
        @test observable((source.slot, target.slot), X ⊗ X) ≈ 1
    end
end
