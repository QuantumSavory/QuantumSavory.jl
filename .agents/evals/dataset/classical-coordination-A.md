QuantumSavory handles classical coordination through a metadata-and-message
layer rather than by forcing direct protocol-to-protocol wiring.

The main pieces are:

- classical channels for sending control traffic across a `RegisterNet`;
- per-node `MessageBuffer`s for receiving that traffic;
- tags attached to register slots to describe quantum resources; and
- queries and waiting helpers for discovering resources or consuming messages.

The intended pattern is:

- send classical information with `put!(channel(...), Tag(...))`;
- consume it from `messagebuffer(net, node)`;
- use `query`, `querydelete!`, `query_wait`, or `querydelete_wait!` to match
  what you need.

This same query style is also used on register metadata, which is why
independently written protocols can coordinate by semantic facts instead of
hard-coded peer handles.

For example:

```julia
put!(channel(net, 1 => 2), Tag(:swap_request))
msg = @yield querydelete_wait!(messagebuffer(net, 2), :swap_request)
```

This fits naturally with the discrete-event simulator, because protocols can
wait for messages, timeouts, or resource availability in the same control-flow
style.

One important design choice in the docs: locality is modeled through graphs,
channels, delays, and message buffers, but it is not enforced at the Julia
language level. That makes localized protocol design possible without banning
more centralized architectures.

