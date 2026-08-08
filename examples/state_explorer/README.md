# Interactive State Explorer

Live version at [areweentangledyet.com/state_explorer/](https://areweentangledyet.com/state_explorer/)

This Makie-based tool can be used to visualize and study two-qubit quantum states.

It is based on `QuantumSavory.StatesZoo.stateexplorer` and can work with the predefined states in `QuantumSavory.StatesZoo` or any other state supporting the necessary interface (e.g. from `QuantumSymbolics` or `QuantumOptics`).

Documentation:

- [`QuantumSavory.StatesZoo.stateexplorer`](https://qs.quantumsavory.org/dev/API_StatesZoo/#QuantumSavory.StatesZoo.stateexplorer)
- [The "Tutorials" doc page about `stateexplorer`](https://qs.quantumsavory.org/dev/tutorial/state_explorer/)

## Server configuration

Run the app with the examples environment:

```bash
julia --project=examples examples/state_explorer/state_explorer.jl
```

The server listens on `127.0.0.1:8896` by default. Configure it with
`QS_STATE_EXPLORER_IP`, `QS_STATE_EXPLORER_PORT`, and
`QS_STATE_EXPLORER_PROXY`. The proxy value is the absolute public URL of the
app, including its trailing slash. For example:

```bash
QS_STATE_EXPLORER_PROXY=https://areweentangledyet.com/state_explorer/ \
    julia --project=examples examples/state_explorer/state_explorer.jl
```

The old `QS_SIMPLESWITCH_IP`, `QS_SIMPLESWITCH_PORT`, and
`QS_SIMPLESWITCH_PROXY` names remain as compatibility fallbacks. A matching
`QS_STATE_EXPLORER_*` value takes precedence.
