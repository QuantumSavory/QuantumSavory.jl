# Bell Memory Explorer

The Bell Memory Explorer is a small interactive app for inspecting how a stored
Bell pair evolves under T2 dephasing.

The source code is in the
[`examples/bell_memory_explorer`](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/bell_memory_explorer)
folder.

Run it from the examples environment:

```julia
julia --project=examples examples/bell_memory_explorer/bell_memory_explorer.jl
```

The app starts a local Bonito/WGLMakie server. By default it listens on
`127.0.0.1:8897`; use `QS_BELL_MEMORY_PORT`, `QS_BELL_MEMORY_IP`, and
`QS_BELL_MEMORY_PROXY` to customize the server configuration.

The sliders control the initial Bell-pair fidelity, memory lifetime, and plotted
time horizon. The app then samples `XX`, `YY`, and `ZZ` stabilizer expectations
from a `Register` initialized with `DepolarizedBellPair`, and displays the Bell
fidelity estimate

```math
F_{\Phi^+} = \frac{1 + XX - YY + ZZ}{4}.
```

This gives a compact first step before larger repeater or switching examples:
users can see which correlations are preserved by the memory noise model and
which decay while the pair waits in storage.
