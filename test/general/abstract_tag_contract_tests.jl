using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo

const PZ = QuantumSavory.ProtocolZoo
const QTCP = PZ.QTCP
const MBQC = PZ.MBQCEntanglementDistillation

struct ContractTag <: AbstractTag end
struct UnrelatedTagHead end

@testset "AbstractTag contract" begin
    @test Base.isexported(QuantumSavory, :AbstractTag)


    net = RegisterNet([Register(1), Register(1)])
    sim = get_time_tracker(net)

    @test fieldtype(EntanglerProt, :tag) == Union{Type{<:AbstractTag},Nothing}
    @test EntanglerProt(sim, net, 1, 2; tag=ContractTag).tag === ContractTag
    @test EntanglerProt(sim, net, 1, 2; tag=nothing).tag === nothing
    @test_throws MethodError EntanglerProt(sim, net, 1, 2; tag=UnrelatedTagHead)
    @test_throws MethodError EntanglerProt(sim, net, 1, 2; tag=Int)

    @test fieldtype(EntanglementConsumer, :tag) == Type{<:AbstractTag}
    @test EntanglementConsumer(sim, net, 1, 2; tag=ContractTag).tag === ContractTag
    @test_throws MethodError EntanglementConsumer(sim, net, 1, 2; tag=nothing)
    @test_throws MethodError EntanglementConsumer(sim, net, 1, 2; tag=UnrelatedTagHead)
    @test_throws MethodError EntanglementConsumer(sim, net, 1, 2; tag=Int)

    generic_tag = Tag(Int, 4, 5)
    @test generic_tag[1] === Int
    reg = Register(1)
    tag!(reg[1], Int, 4, 5)
    @test query(reg, Int, 4, 5).tag == generic_tag

    unrelated_tag = Tag(UnrelatedTagHead, 7)
    @test unrelated_tag[1] === UnrelatedTagHead
    tag!(reg[1], UnrelatedTagHead, 7)
    @test query(reg, UnrelatedTagHead, 7).tag == unrelated_tag
end
