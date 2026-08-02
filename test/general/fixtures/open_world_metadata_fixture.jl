using Test
using QuantumSavory

const ProtocolZoo = QuantumSavory.ProtocolZoo

module ExternalCatalogPackage

using QuantumSavory: AbstractBackground, QuantumStateTrait
using QuantumSavory.ProtocolZoo: AbstractProtocol
import QuantumSavory.ProtocolZoo: permits_virtual_edge, protocol_catalog_metadata

public SlotFamily, PublicSlot, ParametricSlot

abstract type SlotFamily <: QuantumStateTrait end

"""A public slot type supplied by an independent package."""
struct PublicSlot <: QuantumStateTrait end

"""A public parametric slot type supplied by an independent package."""
struct ParametricSlot{T} <: SlotFamily
    "the slot's external payload"
    payload::T
end

struct PrivateSlot <: QuantumStateTrait end

public BackgroundFamily, PublicBackground, ParametricBackground

abstract type BackgroundFamily <: AbstractBackground end

"""A public background supplied by an independent package."""
struct PublicBackground <: AbstractBackground
    "the background rate"
    rate::Float64
end

"""A public parametric background supplied by an independent package."""
struct ParametricBackground{T} <: BackgroundFamily
    "the background model"
    model::T
end

struct PrivateBackground <: AbstractBackground end

public ProtocolFamily, EdgeProtocol, NetworkProtocol, ParametricProtocol,
    LateProtocol, MalformedProtocol

abstract type ProtocolFamily <: AbstractProtocol end

"""A public edge protocol supplied by an independent package."""
struct EdgeProtocol <: AbstractProtocol
    "the injected simulation"
    sim::Any
    "the injected register network"
    net::Any
    "the first topology-supplied endpoint"
    source::Int
    "the second topology-supplied endpoint"
    target::Int
    "the number of attempts"
    attempts::Int
    _scratch::Vector{Int}
end

protocol_catalog_metadata(::Type{EdgeProtocol}) = (
    attachment = :edge,
    attachment_fields = (node_a=:source, node_b=:target),
    required_fields = (:attempts,),
)
permits_virtual_edge(::Type{EdgeProtocol}) = true

"""A public network protocol supplied by an independent package."""
struct NetworkProtocol <: ProtocolFamily
    "the injected simulation"
    sim::Any
    "the injected register network"
    net::Any
    "the network-wide policy"
    policy::Symbol
end

protocol_catalog_metadata(::Type{NetworkProtocol}) = (
    attachment = :network,
    attachment_fields = NamedTuple(),
    required_fields = (),
)

"""A public parametric node protocol supplied by an independent package."""
struct ParametricProtocol{T} <: ProtocolFamily
    "the injected simulation"
    sim::Any
    "the injected register network"
    net::Any
    "the topology-supplied host"
    host::Int
    "the protocol setting"
    setting::T
    _cache::Vector{T}
end

protocol_catalog_metadata(::Type{ParametricProtocol}) = (
    attachment = :node,
    attachment_fields = (node=:host,),
    required_fields = (:setting,),
)

"""A public protocol which opts in after the first catalog query."""
struct LateProtocol <: ProtocolFamily
    "the injected simulation"
    sim::Any
    "the injected register network"
    net::Any
    "the topology-supplied host"
    host::Int
    "the target nodes"
    targets::Vector{Int}
end

"""A public protocol with metadata installed only for the malformed-metadata check."""
struct MalformedProtocol <: ProtocolFamily
    "the injected simulation"
    sim::Any
    "the injected register network"
    net::Any
    "the topology-supplied host"
    host::Int
end

"""A private protocol whose trait method must not make it public."""
struct PrivateProtocol <: AbstractProtocol
    "the injected simulation"
    sim::Any
    "the injected register network"
    net::Any
    "the topology-supplied host"
    host::Int
end

protocol_catalog_metadata(::Type{PrivateProtocol}) = (
    attachment = :node,
    attachment_fields = (node=:host,),
    required_fields = (),
)

end

module CatalogAliases

using ..ExternalCatalogPackage: EdgeProtocol, PublicBackground, PublicSlot

export EdgeProtocol, PrivateSlotAlias, PublicBackground, PublicSlot

const PrivateSlotAlias = Main.ExternalCatalogPackage.PrivateSlot

end

using InteractiveUtils
using REPL

const External = ExternalCatalogPackage

qualified_name(T) = string(parentmodule(T), ".", nameof(T))
catalog_types(catalog) = getproperty.(catalog, :type)

@testset "open-world catalog fixture" begin
    @testset "recursive public discovery" begin
        slots = QuantumSavory.available_slot_types()
        slot_types = catalog_types(slots)
        @test External.PublicSlot in slot_types
        @test External.ParametricSlot in slot_types
        @test External.ParametricSlot isa UnionAll
        @test External.SlotFamily ∉ slot_types
        @test External.PrivateSlot ∉ slot_types
        @test CatalogAliases.PrivateSlotAlias ∉ slot_types
        @test Base.ispublic(CatalogAliases, :PrivateSlotAlias)
        @test count(type -> type === External.PublicSlot, slot_types) == 1
        @test issorted(qualified_name.(slot_types))

        backgrounds = QuantumSavory.available_background_types()
        background_types = catalog_types(backgrounds)
        @test External.PublicBackground in background_types
        @test External.ParametricBackground in background_types
        @test External.ParametricBackground isa UnionAll
        @test External.BackgroundFamily ∉ background_types
        @test External.PrivateBackground ∉ background_types
        @test count(type -> type === External.PublicBackground, background_types) == 1
        @test issorted(qualified_name.(background_types))

        parametric_fields = QuantumSavory.constructor_metadata(External.ParametricBackground)
        @test getproperty.(parametric_fields, :field) == [:model]
        @test only(parametric_fields).type isa TypeVar
    end

    @testset "protocol opt-in and descriptors" begin
        initial = ProtocolZoo.available_protocol_types()
        initial_types = catalog_types(initial)
        @test External.EdgeProtocol in initial_types
        @test External.NetworkProtocol in initial_types
        @test External.ParametricProtocol in initial_types
        @test External.ParametricProtocol isa UnionAll
        @test External.ProtocolFamily ∉ initial_types
        @test External.PrivateProtocol ∉ initial_types
        @test External.LateProtocol ∉ initial_types
        @test External.MalformedProtocol ∉ initial_types
        @test count(type -> type === External.EdgeProtocol, initial_types) == 1
        @test issorted(qualified_name.(initial_types))

        edge = only(filter(entry -> entry.type === External.EdgeProtocol, initial))
        @test edge.nodeargs == 2
        @test edge.attachment === :edge
        @test edge.attachment_fields == (node_a=:source, node_b=:target)
        @test edge.permits_virtual_edge
        @test ProtocolZoo.permits_virtual_edge(External.EdgeProtocol)
        @test getproperty.(edge.parameters, :field) == [:attempts]
        @test only(edge.parameters).required
        @test :sim ∉ getproperty.(edge.parameters, :field)
        @test :net ∉ getproperty.(edge.parameters, :field)
        @test :_scratch ∉ getproperty.(edge.parameters, :field)

        network = only(filter(entry -> entry.type === External.NetworkProtocol, initial))
        @test network.nodeargs == 0
        @test network.attachment === :network
        @test network.attachment_fields == NamedTuple()
        @test getproperty.(network.parameters, :field) == [:policy]
        @test !only(network.parameters).required

        parametric = only(filter(
            entry -> entry.type === External.ParametricProtocol,
            initial,
        ))
        @test parametric.nodeargs == 1
        @test parametric.attachment_fields == (node=:host,)
        @test getproperty.(parametric.parameters, :field) == [:setting]
        @test only(parametric.parameters).type isa TypeVar
        @test only(parametric.parameters).required
        @test :_cache ∉ getproperty.(parametric.parameters, :field)

        repeated_types = catalog_types(ProtocolZoo.available_protocol_types())
        @test repeated_types == initial_types
        @test qualified_name.(repeated_types) == qualified_name.(initial_types)

        Core.eval(External, quote
            protocol_catalog_metadata(::Type{LateProtocol}) = (
                attachment = :node,
                attachment_fields = (node=:host,),
                required_fields = (:targets,),
            )
        end)
        updated = Base.invokelatest(ProtocolZoo.available_protocol_types)
        updated_types = catalog_types(updated)
        @test External.LateProtocol in updated_types
        late = only(filter(entry -> entry.type === External.LateProtocol, updated))
        @test late.nodeargs == 1
        @test getproperty.(late.parameters, :field) == [:targets]
        @test only(late.parameters).required

        @test catalog_types(Base.invokelatest(ProtocolZoo.available_protocol_types)) ==
            updated_types
    end

    @testset "precise malformed metadata error" begin
        Core.eval(External, quote
            protocol_catalog_metadata(::Type{MalformedProtocol}) = (
                attachment = :cluster,
                attachment_fields = (node=:host,),
                required_fields = (),
            )
        end)
        exception = try
            Base.invokelatest(ProtocolZoo.available_protocol_types)
            nothing
        catch error
            error
        end
        @test exception isa ArgumentError
        @test sprint(showerror, exception) ==
            "ArgumentError: invalid protocol catalog metadata for " *
            "Main.ExternalCatalogPackage.MalformedProtocol: attachment must be " *
            ":network, :node, or :edge; got :cluster"
    end
end
