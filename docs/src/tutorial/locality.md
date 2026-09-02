# [Locality-Respecting Protocols](@id tutorial-locality)

This tutorial is one narrow skill: how to write a protocol that only uses
local register access plus classical messages, and how that differs from
reaching into a remote `RegisterNet` vertex.

It is not a full repeater how-to. For the swapper pattern in a larger
protocol, see [Custom Swapper Protocol](@ref) and
[Discrete Event Simulator](@ref sim).

## Setup

```julia
using QuantumSavory
using QuantumSavory.ProtocolZoo: EntanglementCounterpart
using ConcurrentSim, ResumableFunctions

net = RegisterNet([Register(2), Register(2), Register(2)]; classical_delay=1.0)
sim = get_time_tracker(net)
alice, mid, bob = 1, 2, 3
```

Give the middle node two counterpart tags, as if an entangler had already
run. Direct `tag!` on `net[mid]` is local to that node:

```julia
tag!(net[mid][1], EntanglementCounterpart, alice, 1, 0)
tag!(net[mid][2], EntanglementCounterpart, bob, 1, 0)
```

## Nonlocal lookup (legal, not LOCC)

A process that "lives" at Alice can still read the middle register immediately.
No classical delay is applied:

```julia
@resumable function peek_remote(sim, net)
    hit = query(net[mid], EntanglementCounterpart, bob, ❓, ❓)
    return (; t=now(sim), hit)
end

p = @process peek_remote(sim, net)
run(sim)
result = ConcurrentSim.value(p)
result.t  # 0.0 — no wait
result.hit.slot == net[mid][2]
```

That is the shared-memory model. Use it for a centralized controller. Do not
use it if the process is meant to be a node-local networking protocol.

## Local lookup plus a classical request

Alice asks the middle node for a swap over the classical channel. The middle
node waits on its message buffer, then queries only `net[mid]`:

```julia
@resumable function requester(sim, net, src, dst)
    @yield timeout(sim, 0.0)
    put!(channel(net, src => dst), Tag(:swap_request, src))
end

@resumable function local_swapper(sim, net, node)
    mb = messagebuffer(net, node)
    msg = @yield querydelete_wait!(mb, :swap_request, ❓)
    local_hit = query(net[node], EntanglementCounterpart, msg.tag[2], ❓, ❓)
    return (; t=now(sim), src=msg.src, local_hit)
end

sim = get_time_tracker(net)
@process requester(sim, net, alice, mid)
p = @process local_swapper(sim, net, mid)
run(sim)
out = ConcurrentSim.value(p)
out.t          # 1.0 — the classical_delay on alice => mid
out.src == alice
out.local_hit.slot == net[mid][1]
```

The swapper never indexed `net[alice]` or `net[bob]`. Remote coordination
went through `put!` + `querydelete_wait!`. That is the locality convention
from [Locality by Convention](@ref locality-convention).

## Carry this forward

- Preferred tools: `channel`, `messagebuffer`, `put!`, `query_wait`,
  `querydelete_wait!`.
- `RegisterNet` will not stop a nonlocal `query(net[remote], ...)`.
- If a protocol needs instant global visibility, skip the channel and say so
  in the model, rather than accidentally omitting the wait.
