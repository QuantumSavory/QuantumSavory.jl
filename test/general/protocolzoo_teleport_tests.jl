using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo
using ConcurrentSim
using QuantumClifford

@testset "Teleportation" begin
    net = RegisterNet([Register(3), Register(3)])
    sim = get_time_tracker(net)

    # Initialize nodes
    nodeA = 1
    nodeB = 2

    # Set up Entanglement (simulate an existing entangled pair)
    pair_id = fresh_entanglement_id()
    ent_qA = net[nodeA][1]
    ent_qB = net[nodeB][1]

    # Create bell pair |B00>
    initialize!((ent_qA, ent_qB), X1 ⊗ X1)
    apply!((ent_qA, ent_qB), H ⊗ I)
    apply!((ent_qA, ent_qB), CNOT)

    # Tag them as EntanglementCounterpart
    tag!(ent_qA, EntanglementCounterpart, nodeB, 1, pair_id)
    tag!(ent_qB, EntanglementCounterpart, nodeA, 1, pair_id)

    # Initialize state to teleport
    state_q = net[nodeA][2]
    # Let's teleport the |1> state, which corresponds to Z2 (eigenvalue -1)
    initialize!(state_q, Z2)
    
    # Tag the state
    tag!(state_q, StateToTeleport, nodeB)

    # Start protocols
    sender = TeleportSenderProt(net, nodeA; rounds=1)
    receiver = TeleportReceiverProt(net, nodeB; rounds=1)

    @process sender()
    @process receiver()

    run(sim, 20.0)

    # Check if teleportation succeeded
    # the target should be ent_qB
    # The TeleportedState tag should be present
    @test query(ent_qB, TeleportedState, nodeA; assigned=true) !== nothing

    # The state was |1>, measuring it in Z basis should give -1 (which is 2 in QuantumClifford)
    res = project_traceout!(ent_qB, σᶻ)
    @test res == 2
end
