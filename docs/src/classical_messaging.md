# [Classical Messaging and Buffers](@id classical-messaging)

QuantumSavory uses the same metadata-and-query style for classical control that
it uses for register annotations. The transport layer for that control traffic
is built from classical channels and per-node message buffers.

## Direct Classical Links

`channel(net, src => dst)` returns a handle to a direct classical channel
between two adjacent nodes in the `RegisterNet`.

```julia
put!(channel(net, 1 => 2), Tag(:swap_request))
```

Messages sent this way are classical tags, not quantum states. The quantum
transport layer is separate and uses [`qchannel`](@ref).

## Message Buffers Collect Incoming Messages

Each node has a `MessageBuffer` that listens to all incoming classical channels
for that node.

```julia
mb = messagebuffer(net, 2)
msg = querydelete!(mb, :swap_request)
```

This means protocol code usually consumes messages from the node buffer rather
than reading directly from one channel at a time. That is what allows several
protocols to share the same incoming traffic and filter only the messages they
care about.

## Routing With `permit_forward = true`

If two nodes are not directly connected, `channel(net, src => dst)` errors by
default. To request hop-by-hop forwarding across the existing graph, ask for:

```julia
put!(channel(net, 1 => 4; permit_forward = true), Tag(:swap_request))
```

When forwarding is enabled, QuantumSavory computes a shortest path with
`Graphs.a_star` and wraps the message in an internal forwarding tag. Each hop
re-emits the message toward the final destination until it reaches the target
node's `MessageBuffer`.

This is specific to classical traffic. It is not an automatic multi-hop quantum
repeater layer.

## Latency Is Part Of The Simulation

`RegisterNet(...; classical_delay = Δt)` assigns that delay to each direct
classical edge at construction time. Message arrival therefore happens on the
simulation clock, not instantly.

That matters because protocol behavior often depends on classical latency:

- waiting for heralding results,
- propagating swap outcomes,
- and reacting to timeouts or retries.

The transport delay and the discrete-event protocol logic therefore work
together.

## Querying Buffers Is The Usual Consumption Pattern

The most common buffer operations are:

- `query(mb, ...)` to inspect whether a message is present;
- `querydelete!(mb, ...)` to consume one matching message;
- `querydelete_wait!(mb, ...)` to suspend a protocol until such a message
  arrives.

That pattern gives protocols a message-queue style interface without requiring
each pair of protocols to set up bespoke point-to-point plumbing.

## Locality Is By Convention, Not Enforcement

QuantumSavory models network locality through the graph, channels, delays, and
message buffers. It does not try to enforce locality at the Julia language
level. A protocol that already has a reference to remote data can still use it.

This is a deliberate tradeoff. Some simulations need centralized controllers or
global schedulers that are allowed to inspect the whole network immediately.
The framework therefore provides the communication abstractions needed for
localized protocol design, but it does not forbid other architectural choices.

## Why This Matters For Composability

This transport layer is what makes the metadata plane practical. Protocols can
publish facts into message buffers, consume matching facts when they become
relevant, and stay decoupled from the internal implementation of other
protocols.

That is more reusable than building every simulation around one fixed object
graph of callbacks and explicit peer handles.

## Where To Go Next

- Read [Metadata and Protocol Composition](@ref metadata-plane) for the higher
  level view of why this control style is useful.
- Read [Tag and Query API](tag_query.md) for the matching and consumption
  primitives used on buffers.
- Read [Discrete Event Simulator](@ref sim) for the waiting side of message
  handling.
