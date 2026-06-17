# Custom Swapper Protocol

This guide is a complete runnable version of the `MySwapperProt` sketch shown
in the [QuantumSavory paper](https://arxiv.org/abs/2512.16752). The paper uses
the sketch to explain how tags, queries, message buffers, and discrete-event
protocols fit together. Here we turn that sketch into a small working repeater
chain.

The example is intentionally simple and explicit. It is a good first look at
how QuantumSavory models a repeater node that waits for a classical request,
finds the two local Bell-pair halves it needs, performs a local Bell
measurement, and sends classical update messages to the endpoints.

For production-style simulations, QuantumSavory already provides a more
polished and automated version of this workflow in [`ProtocolZoo`](@ref
"Predefined Networking Protocols"): [`SwapperProt`](@ref) performs the swaps,
[`EntanglementTracker`](@ref) handles the endpoint bookkeeping, and the rest of
the repeater suite manages repeated attempts and metadata updates. After this
guide, the natural follow-up is the [First Generation Quantum Repeater](@ref
First-Generation-Quantum-Repeater-ProtocolZoo) how-to, which uses that suite.

The complete source is in
[`examples/myswapper_tutorial`](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/myswapper_tutorial).

## Setup

We use a three-node chain: Alice is node 1, Bob is node 2, and Charlie is node 3.
Bob starts with one qubit entangled with Alice and another qubit entangled with
Charlie. The tutorial manually prepares those two Bell pairs so that we can
focus on the swapper protocol itself.

The example follows the same structure as the other in-repo examples:
`setup.jl` contains the reusable setup function, and `my_swapper_prot.jl`
contains the custom protocol and runnable script.

```julia
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
```

The setup function creates the chain, prepares the two initial Bell pairs, and
tags each slot with the existing `ProtocolZoo` `EntanglementCounterpart` tag.
The tag fields are:

- the remote node,
- the remote slot,
- and the pair id.

```julia
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

    # The protocol definitions are in my_swapper_prot.jl.
    @process MySwapperProt(sim, net, 2, 1, 3)()
    @process endpoint_update(sim, net, 1, 2, :swap_update_z)
    @process endpoint_update(sim, net, 3, 2, :swap_update_x)

    put!(channel(net, 1 => 2), Tag(:swap_request))
    run(sim, 1.0)

    alice_final = query(net[1], EntanglementCounterpart, 3, W, W)
    charlie_final = query(net[3], EntanglementCounterpart, 1, W, W)

    return (; sim, net, alice_final, charlie_final)
end
```

The important point is that the quantum state and the classical metadata are
separate. The Bell pair is the quantum resource; the `EntanglementCounterpart`
tag is the classical fact that lets later protocols find that resource.

## The Swapper

`MySwapperProt` is a small protocol object. It carries the simulation context
and the node identities it needs:

```julia
struct MySwapperProt <: AbstractProtocol
    sim::Simulation
    net::RegisterNet
    node::Int
    alice::Int
    charlie::Int
end
```

The protocol starts by waiting on Bob's message buffer. No direct handle to the
requesting protocol is needed; the only contract is that a `:swap_request`
message arrives.

```julia
@resumable function (prot::MySwapperProt)()
    (; sim, net, node, alice, charlie) = prot
    reg = net[node]
    mb = messagebuffer(net, node)

    @yield querydelete_wait!(mb, :swap_request)
```

Once the request arrives, Bob queries his own register for one slot entangled
with Alice and one slot entangled with Charlie. The wildcard fields mean "any
remote slot" and "any pair id".

```julia
    a = query(reg, EntanglementCounterpart, alice, W, W; locked=false, assigned=true)
    b = query(reg, EntanglementCounterpart, charlie, W, W; locked=false, assigned=true)
    @assert !isnothing(a) "No local slot at node $(node) is tagged as entangled with Alice."
    @assert !isnothing(b) "No local slot at node $(node) is tagged as entangled with Charlie."
```

Before measuring the two local qubits, the protocol locks them and then
re-checks that the tags are still current. This is the main concurrency lesson
in the example: query results are snapshots, and a protocol can yield while it
waits for locks.

```julia
    q_alice = a.slot
    q_charlie = b.slot
    @yield lock(q_alice) & lock(q_charlie)

    current_a = query(q_alice, a.tag; assigned=true)
    current_b = query(q_charlie, b.tag; assigned=true)
    if isnothing(current_a) || isnothing(current_b)
        unlock(q_alice)
        unlock(q_charlie)
        return nothing
    end

    untag!(q_alice, current_a.id)
    untag!(q_charlie, current_b.id)
```

Now Bob can perform the local Bell measurement. The two original pair ids are
combined into the pair id for the new Alice-Charlie entanglement, and Bob sends
one explicit update message to each endpoint.

```julia
    xmeas, zmeas = LocalEntanglementSwap()(q_alice, q_charlie)
    new_pair_id = combine_entanglement_ids(a.tag[4], b.tag[4])

    put!(
        channel(net, node => alice),
        Tag(:swap_update_z, q_alice.idx, b.tag[2], b.tag[3], Int(xmeas), new_pair_id),
    )
    put!(
        channel(net, node => charlie),
        Tag(:swap_update_x, q_charlie.idx, a.tag[2], a.tag[3], Int(zmeas), new_pair_id),
    )

    unlock(q_alice)
    unlock(q_charlie)
    return (xmeas, zmeas)
end
```

This is the core idea from the paper's example: Bob does not need to know who
implemented the request. Alice and Charlie do not need direct access to Bob's
protocol object. The protocols coordinate through tags and message buffers.

## Endpoint Updates

The full `ProtocolZoo` workflow uses [`EntanglementTracker`](@ref) for this
step. This tutorial keeps the bookkeeping explicit so the data movement is
visible.

Each endpoint waits for its update message, removes the old Bob-facing
`EntanglementCounterpart`, applies the Pauli correction if needed, and tags the
same slot as entangled with the other endpoint.

```julia
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
```

## Run It

The runnable script includes `setup.jl`, defines the custom protocol, runs the
setup, and leaves the final query results available for inspection:

```julia
include("setup.jl")

tutorial_result = build_myswapper_tutorial()
sim = tutorial_result.sim
net = tutorial_result.net
alice_final = tutorial_result.alice_final
charlie_final = tutorial_result.charlie_final
```

After the simulation, Alice and Charlie have reciprocal endpoint tags:

```julia
alice_final = query(net[1], EntanglementCounterpart, 3, W, W)
charlie_final = query(net[3], EntanglementCounterpart, 1, W, W)
```

The value of this guide is pedagogical. It shows the moving parts that the
high-level repeater protocols automate: classical requests, message buffers,
resource tags, slot locking, local quantum operations, measurement-dependent
messages, and endpoint metadata updates.

For a more complete repeater simulation built from reusable ProtocolZoo
components, continue with [First Generation Quantum Repeater](@ref
First-Generation-Quantum-Repeater-ProtocolZoo).
