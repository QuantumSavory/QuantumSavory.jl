using Graphs
using ConcurrentSim
using ResumableFunctions

using QuantumSavory
using QuantumSavory.CircuitZoo: LocalEntanglementSwap
using QuantumSavory.ProtocolZoo:
    AbstractProtocol,
    EntanglementCounterpart,
    combine_entanglement_ids,
    fresh_entanglement_id

function build_myswapper_tutorial()
    registers = [Register(2), Register(2), Register(2)]
    net = RegisterNet(path_graph(3), registers; classical_delay=0.1)
    sim = get_time_tracker(net)

    initialize!((net[1][1], net[2][1]), StabilizerState("ZZ XX"))
    initialize!((net[2][2], net[3][1]), StabilizerState("ZZ XX"))

    alice_bob_pair_id = fresh_entanglement_id()
    bob_charlie_pair_id = fresh_entanglement_id()

    tag!(net[1][1], EntanglementCounterpart, 2, 1, alice_bob_pair_id)
    tag!(net[2][1], EntanglementCounterpart, 1, 1, alice_bob_pair_id)
    tag!(net[2][2], EntanglementCounterpart, 3, 1, bob_charlie_pair_id)
    tag!(net[3][1], EntanglementCounterpart, 2, 2, bob_charlie_pair_id)

    @process MySwapperProt(sim, net, 2, 1, 3)()
    @process endpoint_update(sim, net, 1, 2, :swap_update_z)
    @process endpoint_update(sim, net, 3, 2, :swap_update_x)

    put!(channel(net, 1 => 2), Tag(:swap_request))
    run(sim, 1.0)

    alice_final = query(net[1], EntanglementCounterpart, 3, W, W)
    charlie_final = query(net[3], EntanglementCounterpart, 1, W, W)

    return (; sim, net, alice_final, charlie_final)
end

