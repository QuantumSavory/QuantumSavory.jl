# QTCP with External Link Inventory

A QTCP [`LinkController`](@ref) can generate one physical pair for each link
request, or it can claim pairs made by independent producers. External inventory
is useful when pair generation must run continuously or use a separate policy.

The complete runnable version is
[`examples/qtcp_tutorial/5_external_entanglement_inventory.jl`](https://github.com/QuantumSavory/QuantumSavory.jl/blob/master/examples/qtcp_tutorial/5_external_entanglement_inventory.jl).
Run it from the repository root with:

```sh
julia --project=examples examples/qtcp_tutorial/5_external_entanglement_inventory.jl
```

## Configure The Producers And Consumers

Start one external-mode link controller and one persistent entangler on every
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

The configured tag type is the inventory interface between the two protocols.
`EntanglementCounterpart` includes `(remote_node, remote_slot, pair_id)`.
Custom tag types use `(remote_node, remote_slot)` and must be concrete subtypes
of `AbstractTag`.

The two supported controller configurations are:

| Mode | `tag` | `filo` |
| --- | --- | --- |
| Integrated generation | `nothing` | `nothing` |
| External inventory | Concrete `AbstractTag` subtype | `true` or `false` |

External mode defaults to `filo=true`, which selects the newest suitable pair.
Use `filo=false` to select the oldest. Mixed configurations are rejected.

## Submit Flows Independently

The producers and link controllers run independently. Submit traffic without
waiting for every edge to have inventory:

```julia
flow1 = Flow(src=1, dst=4, npairs=5, uuid=1)
flow2 = Flow(src=13, dst=16, npairs=5, uuid=2)
put!(net[flow1.src], flow1)
put!(net[flow2.src], flow2)
run(sim, 300.0)
```

If a request reaches an edge before its producer makes a pair, the link
controller waits until suitable reciprocal inventory appears.

## What A Claim Does

For each request, the link controller waits for a valid reciprocal pair, locks
both slots, and revalidates their assignments and tags. A successful claim
removes the two inventory tags but retains the shared quantum state for QTCP.
Malformed, stale, duplicated, or concurrently changed metadata is not partly
consumed.

`SwapperProt` and `CutoffProt` remain separate protocol components. They are not
started or reconfigured by external-inventory mode.
