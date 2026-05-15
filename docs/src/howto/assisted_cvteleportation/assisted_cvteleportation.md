# Assisted Continuous-Variable Teleportation

This how-to shows a three-node assisted continuous-variable teleportation
protocol built with `Qumode` registers and the `Gabs.jl` Gaussian backend.

Alice starts with an unknown coherent input state. Alice, Bob, and Charlie also
share a three-mode Gaussian resource. Alice performs the Bell-like homodyne
measurement, Charlie sends an assisting homodyne result, and Bob combines both
classical messages into the final displacement correction.

The source code is in the
[`examples/assisted_cvteleportation`](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/assisted_cvteleportation)
folder.

## Running the Script

The non-interactive script runs one teleportation instance and checks that the
teleported state is close to the input state:

```julia
julia --project=examples examples/assisted_cvteleportation/setup.jl
```

The interactive WGLMakie dashboard exposes the coherent input amplitude, input
phase, and resource squeezing:

```julia
julia --project=examples examples/assisted_cvteleportation/1_interactive_visualization.jl
```

The dashboard compares the input and teleported output Wigner functions, plots
the residual difference, and reports the Gaussian-state fidelity. Larger
resource squeezing produces a higher-fidelity output state.

## What This Example Teaches

- Continuous-variable registers through `Qumode` and `GabsRepr(QuadBlockBasis)`.
- Gaussian-state preparation with coherent and squeezed input states.
- Beam-splitter, phase-shift, homodyne, and displacement operations.
- Classical message passing through `channel`, `Tag`, `messagebuffer`, and
  `query_wait`.
- Packaging a single teleportation round as a callable `AbstractProtocol`.
- Reusing the same simulation core from both tests and an interactive
  visualization.
