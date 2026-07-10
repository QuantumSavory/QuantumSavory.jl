export TeleportSenderProt, TeleportReceiverProt, StateToTeleport, TeleportMessage, TeleportedState

"""
$TYPEDEF

A tag to designate a qubit to be teleported to a target node.

$TYPEDFIELDS
"""
@kwdef struct StateToTeleport
    "node to send the state to"
    nodeH::Int
end
Base.show(io::IO, tag::StateToTeleport) = print(io, "StateToTeleport to $(tag.nodeH)")
Tag(tag::StateToTeleport) = Tag(StateToTeleport, tag.nodeH)

"""
$TYPEDEF

A tag to designate a qubit that has been teleported from a remote node.

$TYPEDFIELDS
"""
@kwdef struct TeleportedState
    "node that sent the state"
    sender::Int
end
Base.show(io::IO, tag::TeleportedState) = print(io, "TeleportedState from $(tag.sender)")
Tag(tag::TeleportedState) = Tag(TeleportedState, tag.sender)

"""
$TYPEDEF

A classical message sent from a `TeleportSenderProt` to a `TeleportReceiverProt` with the measurement outcomes.

$TYPEDFIELDS
"""
@kwdef struct TeleportMessage
    "the id of the pair that was consumed"
    target_pair_id::EntanglementID
    "x measurement outcome (controls Z correction)"
    xmeas::Int
    "z measurement outcome (controls X correction)"
    zmeas::Int
end
Base.show(io::IO, tag::TeleportMessage) = print(io, "TeleportMessage for pair $(tag.target_pair_id): X=$(tag.xmeas), Z=$(tag.zmeas)")
Tag(tag::TeleportMessage) = Tag(TeleportMessage, tag.target_pair_id, tag.xmeas, tag.zmeas)

"""
$TYPEDEF

A protocol, running at a given node, that finds a qubit tagged with `StateToTeleport` and an `EntanglementCounterpart` to the target node, and performs the teleportation sending a `TeleportMessage`.

$TYPEDFIELDS
"""
@kwdef struct TeleportSenderProt <: AbstractProtocol
    sim::Simulation
    net::RegisterNet
    node::Int
    rounds::Int = -1
end

TeleportSenderProt(net::RegisterNet, node::Int; kwargs...) = TeleportSenderProt(get_time_tracker(net), net, node; kwargs...)

@resumable function (prot::TeleportSenderProt)()
    rounds = prot.rounds
    while rounds != 0
        # Wait until there is a StateToTeleport tag
        state_query = query(prot.net[prot.node], StateToTeleport, ❓; locked=false, assigned=true)
        if isnothing(state_query)
            @yield onchange(prot.net[prot.node], Tag)
            continue
        end
        q_state, tag_state = state_query.slot, state_query.tag
        target_node = tag_state[2]::Int

        # Find an entanglement counterpart with the target_node
        ent_query = query(prot.net[prot.node], EntanglementCounterpart, target_node, ❓, ❓; locked=false, assigned=true)
        if isnothing(ent_query)
            @yield onchange(prot.net[prot.node], Tag)
            continue
        end
        q_ent, tag_ent = ent_query.slot, ent_query.tag

        if q_state.idx == q_ent.idx
            @yield onchange(prot.net[prot.node], Tag)
            continue
        end

        @yield lock(q_state) & lock(q_ent)

        current_state = query(q_state, tag_state; assigned=true)
        current_ent = query(q_ent, tag_ent; assigned=true)
        if isnothing(current_state) || isnothing(current_ent)
            unlock(q_state)
            unlock(q_ent)
            continue
        end

        untag!(q_state, state_query.id)
        untag!(q_ent, ent_query.id)

        uptotime!((q_state, q_ent), now(prot.sim))
        
        swapcircuit = LocalEntanglementSwap()
        xmeas, zmeas = swapcircuit(q_state, q_ent)

        msg = Tag(TeleportMessage, tag_ent[4]::EntanglementID, Int(xmeas), Int(zmeas))
        put!(channel(prot.net, prot.node=>target_node; permit_forward=true), msg)
        
        unlock(q_state)
        unlock(q_ent)
        
        if rounds > 0
            rounds -= 1
        end
    end
end

"""
$TYPEDEF

A protocol, running at a receiving node, that waits for a `TeleportMessage` and applies the corresponding Paulis to the entangled qubit.

$TYPEDFIELDS
"""
@kwdef struct TeleportReceiverProt <: AbstractProtocol
    sim::Simulation
    net::RegisterNet
    node::Int
    rounds::Int = -1
end

TeleportReceiverProt(net::RegisterNet, node::Int; kwargs...) = TeleportReceiverProt(get_time_tracker(net), net, node; kwargs...)

@resumable function (prot::TeleportReceiverProt)()
    rounds = prot.rounds
    mb = messagebuffer(prot.net, prot.node)
    while rounds != 0
        msg_query = @yield querydelete_wait!(mb, TeleportMessage, ❓, ❓, ❓)
        tag_msg = msg_query.tag
        target_pair_id = tag_msg[2]::EntanglementID
        xmeas = tag_msg[3]::Int
        zmeas = tag_msg[4]::Int
        
        ent_query = @yield query_wait(prot.net[prot.node], EntanglementCounterpart, ❓, ❓, target_pair_id; locked=false, assigned=true)
        q_ent, tag_ent = ent_query.slot, ent_query.tag
        
        @yield lock(q_ent)
        
        current_ent = query(q_ent, tag_ent; assigned=true)
        if isnothing(current_ent)
            unlock(q_ent)
            continue
        end
        
        untag!(q_ent, ent_query.id)
        
        if xmeas == 2
            apply!(q_ent, Z)
        end
        if zmeas == 2
            apply!(q_ent, X)
        end
        
        tag!(q_ent, TeleportedState, tag_ent[2])
        
        unlock(q_ent)
        
        if rounds > 0
            rounds -= 1
        end
    end
end
