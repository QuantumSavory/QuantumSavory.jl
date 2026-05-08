using Test
using ConcurrentSim
using QuantumSavory
using QuantumSavory.ProtocolZoo:
    SwapperProt, EntanglementCounterpart, EntanglementHistory
using ResumableFunctions

@testset "ProtocolZoo Swapper stale query result" begin
    net = RegisterNet([Register(1), Register(2), Register(1)])
    sim = get_time_tracker(net)
    qlow = net[2][1]
    qhigh = net[2][2]
    bell = (Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2.0)

    initialize!((net[1][1], qlow), bell)
    initialize!((qhigh, net[3][1]), bell)
    tag!(net[1][1], EntanglementCounterpart, 2, 1)
    tag!(qlow, EntanglementCounterpart, 1, 1)
    tag!(qhigh, EntanglementCounterpart, 3, 1)
    tag!(net[3][1], EntanglementCounterpart, 2, 2)

    selected_lock_taken = Ref(false)
    selected_tag_deleted = Ref(false)

    @resumable function delete_selected_tag(sim)
        deleted = querydelete!(qlow, EntanglementCounterpart, 1, 1)
        selected_tag_deleted[] = !isnothing(deleted)
        @yield timeout(sim, 1.0)
        unlock(qlow)
    end

    function choose_low(_)
        if !selected_lock_taken[]
            # Pin the slot after queryall has selected it but before SwapperProt yields on its lock.
            request(qlow)
            selected_lock_taken[] = true
            @process delete_selected_tag(sim)
        end
        return 1
    end

    swapper = SwapperProt(sim, net, 2;
        nodeL = 1,
        nodeH = 3,
        chooseL = choose_low,
        chooseH = _ -> 1,
        rounds = 1,
        retry_lock_time = 0.25,
    )
    @process swapper()
    run(sim, 1.1)

    @test selected_tag_deleted[]
    @test !islocked(qlow)
    @test !islocked(qhigh)
    @test isnothing(query(qlow, EntanglementCounterpart, 1, 1))
    @test !isnothing(query(qhigh, EntanglementCounterpart, 3, 1))
    @test isempty(queryall(qlow, EntanglementHistory, ❓, ❓, ❓, ❓, ❓))
    @test isempty(queryall(qhigh, EntanglementHistory, ❓, ❓, ❓, ❓, ❓))
end
