# [Locality by Convention](@id locality-convention)

QuantumSavory's tags-and-queries mechanism is the native way for simulated
processes to interact without hard-wiring direct protocol handles. Protocols
publish semantic facts as tags on register slots or as messages in node-local
[`MessageBuffer`](@ref)s, and other protocols discover or consume those facts
through queries.

One subtle consequence is that **locality is enforced by convention, not by
the Julia API, the compiler, or a semantic checker**. A protocol that has a
handle to the full [`RegisterNet`](@ref) can inspect or mutate a remote
register immediately, even if a physically local implementation would have to
send a classical message and wait for the propagation delay. That is typical
of shared-memory interaction models: composition and experimentation stay
easy, but nothing automatically rejects a nonlocal access pattern.

This page is the explicit documentation of that convention. It does not add a
checker or a protocol-annotation macro; those remain possible future work and
are not part of the default API.

## What "local" means in a protocol

A locality-respecting protocol running at node `n` should:

- read and write only `net[n]` (and its slots) for quantum state and register
  tags;
- send classical control through [`channel`](@ref) / [`put!`](@ref);
- receive classical control from [`messagebuffer`](@ref)`(net, n)`;
- wait with [`query_wait`](@ref), [`querydelete_wait!`](@ref),
  [`onchange`](@ref), [`timeout`](@ref), and slot [`lock`](@ref).

The tools that make that style natural are:

| Tool | Role |
|:--|:--|
| `channel(net, src => dst)` | send a classical tag along a (possibly delayed) link |
| `messagebuffer(net, n)` | consume incoming classical tags at node `n` |
| `put!(channel(...), tag)` | enqueue that classical message |
| `query` / `querydelete!` | inspect or consume local register tags or buffer messages |
| `query_wait` / `querydelete_wait!` | suspend until a local match exists, then optionally consume it |

Quantum transport uses [`qchannel`](@ref) / `put!` / `take!` on a direct
edge. It is also a locality-respecting tool, but it moves a quantum state,
not a control message. There is no quantum equivalent of
`permit_forward = true`; multi-hop quantum delivery is a protocol, not a
channel feature.

## Direct `RegisterNet` access is allowed on purpose

This freedom is sometimes the right model:

- a centralized controller that really does see the whole network;
- a local laboratory controller with instant access to several devices in one
  room;
- a higher-level protocol where global inspection is the intended abstraction,
  not an accident.

In those cases, writing `query(net[remote], ...)` or `apply!(net[remote][1],
...)` from a process that "lives" at another node is not a bug. It is an
explicit choice to ignore propagation delay and LOCC constraints.

For networking protocols that are meant to represent distributed LOCC
behavior, that same pattern *is* a modeling error. The Julia types will not
catch it. The discrete-event clock will not insert a delay just because the
access was remote. Users should instead stay on the local register plus the
classical channel / message-buffer path.

## A local swapper versus a nonlocal one

The local version waits for a request in the node buffer, then queries only
the local register:

```julia
@resumable function local_swapper(net, node, alice, charlie)
    mb = messagebuffer(net, node)
    @yield querydelete_wait!(mb, :swap_request)
    a = query(net[node], EntanglementCounterpart, alice, ❓, ❓)
    b = query(net[node], EntanglementCounterpart, charlie, ❓, ❓)
    # lock, swap, send corrections back through `channel` ...
    return a, b
end
```

The nonlocal version reaches into Alice's register from the middle node.
It is legal Julia and it will run; it just is not a distributed protocol:

```julia
@resumable function nonlocal_swapper(net, node, alice, charlie)
    # no message wait: inspect Alice immediately
    a_remote = query(net[alice], EntanglementCounterpart, node, ❓, ❓)
    return a_remote
end
```

The difference is not an API flag. It is whether the protocol uses
`channel` / `messagebuffer` / wait helpers for remote facts, or whether it
dereferences `net[remote]` directly.

## What is not provided

- There is no trait, macro, or linter that rejects `net[remote]` inside a
  protocol body.
- [`RegisterNet`](@ref) indexing is not scoped to a node. `net[i]` is as
  available to a process at node `j` as it is to a process at node `i`.
- Classical `permit_forward` does not make a protocol local; it only routes
  an already-sent message across existing edges.

A future optional annotation that checks for locality-respecting patterns
would be valuable, and it should remain opt-in so centralized controllers
keep working. That checker is not in this release.

## Where to go next

- [Classical Messaging and Buffers](@ref classical-messaging) for `channel`,
  `messagebuffer`, delays, and forwarding.
- [Tag and Query API](@ref tagging-and-querying) for `query`,
  `querydelete!`, and the consuming-wait helpers.
- [Discrete Event Simulator](@ref sim) for `@resumable` protocols that wait
  on those tools.
- [Locality-Respecting Protocols](@ref tutorial-locality) for a runnable
  comparison of the two styles.
