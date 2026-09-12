# QTCP

QTCP is a connectionless entanglement-distribution architecture that turns
application-level `Flow` requests into end-to-end Bell pairs: end-node
controllers create QDatagrams, network-node controllers route them and perform
hop-by-hop swaps, and link controllers supply the physical entanglement for
each hop. The runnable tutorial develops this stack through a
[basic repeater chain](https://github.com/QuantumSavory/QuantumSavory.jl/blob/master/examples/qtcp_tutorial/1_chain_basic.jl),
[live chain visualization](https://github.com/QuantumSavory/QuantumSavory.jl/blob/master/examples/qtcp_tutorial/2_chain_visualization.jl),
[concurrent flows on a grid](https://github.com/QuantumSavory/QuantumSavory.jl/blob/master/examples/qtcp_tutorial/3_grid_multiflow.jl),
[custom end-node controller](https://github.com/QuantumSavory/QuantumSavory.jl/blob/master/examples/qtcp_tutorial/4_custom_endnode.jl),
and [independent link-entanglement producers](https://github.com/QuantumSavory/QuantumSavory.jl/blob/master/examples/qtcp_tutorial/5_external_entanglement_inventory.jl).
Those examples show how to assemble and vary the complete QTCP stack.
In this doc page will will discuss only the last step as a prototypical example of
how different families of protocols can be used together as long as they
agree on the meaning of the tags they use to record and signal classical metadata.

A QTCP [`LinkController`](@ref) can generate one physical pair for each link
request, or it can rely on independent producers like `EntanglerProt`.

The complete runnable version is
[`examples/qtcp_tutorial/5_external_entanglement_inventory.jl`](https://github.com/QuantumSavory/QuantumSavory.jl/blob/master/examples/qtcp_tutorial/5_external_entanglement_inventory.jl).
Run it from the repository root with:

```sh
julia --project=examples examples/qtcp_tutorial/5_external_entanglement_inventory.jl
```

## Configure The Producers And Consumers

Start one link controller and one persistent entangler (which will provide the entanglement needed by the link controller but also potentially by other independent protocols) on every
physical edge of an existing `RegisterNet`:

```julia
using ConcurrentSim
using Graphs
using QuantumSavory
using QuantumSavory.ProtocolZoo

for edge in edges(net)
    controller = LinkController(
        net,
        edge.src,
        edge.dst;
        tag=EntanglementCounterpart,
        filo=true,
    )
    @process controller()

    producer = EntanglerProt(
        net,
        edge.src,
        edge.dst;
        tag=EntanglementCounterpart,
        rounds=-1,
        attempts=-1,
        success_prob=1.0,
        attempt_time=0.1,
        retry_lock_time=0.1,
        randomize=true,
        margin=18,
        hardmargin=10,
    )
    @process producer()
end
```

The configured tag (here `EntanglementCounterpart`) is the interface between the two protocols.
Every generated tag pair must contain
`(remote_node, remote_slot, pair_id)` - the reciprocal
tags in the pair must use the same pair ID.
The link controller treats these exact reciprocal tags as authoritative inventory
metadata. It does not inspect the simulator's quantum-state internals. The producer
and any metadata-tracking protocols are responsible for keeping the tags accurate.

The two supported controller configurations are:

| Mode | `tag` | `filo` |
| --- | --- | --- |
| Integrated generation | `nothing` | `nothing` |
| External generation | Concrete `AbstractTag` subtype | `true` or `false` |

## Submit Flows Independently

The low-level entanglement producers and link controllers run independently. Once they are running, you can submit QTCP traffic:

```julia
flow1 = Flow(src=1, dst=4, npairs=5, uuid=1)
flow2 = Flow(src=13, dst=16, npairs=5, uuid=2)
put!(net[flow1.src], flow1)
put!(net[flow2.src], flow2)
run(sim, 300.0)
```

If a request reaches an edge that does not yet posses link-level pairs, the link
controller waits until the entangler generates such a pair.
