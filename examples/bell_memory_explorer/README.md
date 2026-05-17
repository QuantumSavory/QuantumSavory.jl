# Bell Memory Explorer

This interactive example explores how a noisy Bell pair changes while it is
stored in memories with T2 dephasing.

The app exposes sliders for:

- the initial Bell-pair fidelity,
- the T2 memory lifetime,
- the plotted time horizon.

It plots the `XX`, `YY`, and `ZZ` stabilizer expectations together with the
corresponding Bell-state fidelity estimate. It is intended as a compact way to
build intuition about memory noise before moving on to the repeater, switch, and
congestion examples.

Run it from the examples environment:

```julia
julia --project=examples examples/bell_memory_explorer/bell_memory_explorer.jl
```

By default the app listens on `127.0.0.1:8897`. The port, interface, and proxy
URL can be changed with `QS_BELL_MEMORY_PORT`, `QS_BELL_MEMORY_IP`, and
`QS_BELL_MEMORY_PROXY`.
