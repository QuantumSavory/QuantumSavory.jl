include("setup.jl")

struct MySwapperProt <: AbstractProtocol
    sim::Simulation
    net::RegisterNet
    node::Int
    alice::Int
    charlie::Int
end

@resumable function (prot::MySwapperProt)()
    (; sim, net, node, alice, charlie) = prot
    reg = net[node]
    mb = messagebuffer(net, node)

    @yield querydelete_wait!(mb, :swap_request)

    a = query(reg, EntanglementCounterpart, alice, W, W; locked=false, assigned=true)
    b = query(reg, EntanglementCounterpart, charlie, W, W; locked=false, assigned=true)
    @assert !isnothing(a) "No local slot at node $(node) is tagged as entangled with Alice."
    @assert !isnothing(b) "No local slot at node $(node) is tagged as entangled with Charlie."

    # let's lock the involved qubits for the duration of the swap operation to prevent interference from other protocols
    q_alice = a.slot
    q_charlie = b.slot
    @yield lock(q_alice) & lock(q_charlie)

    # After we gain the locks, we check again that the tags are still there, since other protocols might have edited them
    current_a = query(q_alice, a.tag; assigned=true)
    current_b = query(q_charlie, b.tag; assigned=true)
    if isnothing(current_a) || isnothing(current_b)
        unlock(q_alice)
        unlock(q_charlie)
        return nothing
    end

    # We can delete these tags, since the swap will measure these qubits out
    untag!(q_alice, current_a.id)
    untag!(q_charlie, current_b.id)

    xmeas, zmeas = LocalEntanglementSwap()(q_alice, q_charlie)

    # Derives the new pair id from the old pair ids
    new_pair_id = combine_entanglement_ids(a.tag[4], b.tag[4])

    # We send the measurement results to Alice and Charlie.
    put!(
        channel(net, node => alice),
        Tag(:swap_update_z, q_alice.idx, b.tag[2], b.tag[3], Int(xmeas), new_pair_id),
    )
    put!(
        channel(net, node => charlie),
        Tag(:swap_update_x, q_charlie.idx, a.tag[2], a.tag[3], Int(zmeas), new_pair_id),
    )

    # Finally, we can unlock the qubits
    unlock(q_alice)
    unlock(q_charlie)
    return (xmeas, zmeas)
end

@resumable function endpoint_update(sim, net, node, old_neighbor, update_tag)
    mb = messagebuffer(net, node)
    msg = @yield querydelete_wait!(mb, update_tag, W, W, W, W, W)

    old_neighbor_slot = msg.tag[2]
    new_remote_node = msg.tag[3]
    new_remote_slot = msg.tag[4]
    correction = msg.tag[5]
    new_pair_id = msg.tag[6]

    old_tag = querydelete!(
        net[node],
        EntanglementCounterpart,
        old_neighbor,
        old_neighbor_slot,
        W,
    )
    @assert !isnothing(old_tag) "Endpoint $(node) did not have the expected old entanglement tag."

    if correction == 2
        if update_tag == :swap_update_z
            apply!(old_tag.slot, Z)
        elseif update_tag == :swap_update_x
            apply!(old_tag.slot, X)
        end
    end

    tag!(old_tag.slot, EntanglementCounterpart, new_remote_node, new_remote_slot, new_pair_id)
    return old_tag.slot.idx
end

tutorial_result = build_myswapper_tutorial()
sim = tutorial_result.sim
net = tutorial_result.net
alice_final = tutorial_result.alice_final
charlie_final = tutorial_result.charlie_final
