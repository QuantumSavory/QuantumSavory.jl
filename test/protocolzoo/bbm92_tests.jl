using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo

@testset "BBM92 Protocol Tests" begin
    net = RegisterNet([Register(4), Register(4)])
    prot = BBM92Prot(get_time_tracker(net), net, 1, 2)

    @test BBM92Prot(net, 1, 2) isa BBM92Prot
    @test_throws DomainError BBM92Prot(net, 1, 2; basis_prob=1.1)
    @test_throws DomainError BBM92Prot(net, 1, 2; sifting_fraction=1.1)
    @test_throws DomainError BBM92Prot(net, 1, 2; qber_threshold=-0.1)

    @testset "Protocol Execution" begin
        prot_task = @process prot()
        run!(get_time_tracker(net), until=10.0)
        terminate(prot_task)
        wait(prot_task)
        @test length(net[1].slots) == 4
        @test length(net[2].slots) == 4
        @test terminated(prot_task)
    end

    @testset "QBER Estimation" begin
        reg = Register(2)
        for slot in reg
            store!(slot, :key_bit, rand())
        end
        qber = estimate_qber(reg)
        @test 0.0 ≤ qber ≤ 1.0
        # Test error detection
        store!(reg[1], :partner_key_bit, 1 - reg[1].metadata[:key_bit])
        qber = estimate_qber(reg)
        @test qber == 0.5
        @test 0.0 ≤ qber ≤ 1.0
    end
end