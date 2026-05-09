# Assisted CV Teleportation

This example implements the assisted continuous-variable teleportation protocol
from [arxiv:quant-ph/0604027](https://arxiv.org/abs/quant-ph/0604027) using
[Gabs.jl](https://github.com/QuantumSavory/Gabs.jl) as the Gaussian backend.

## What This Example Does

The tutorial script in `setup.jl` builds a three-node continuous-variable
network for Alice, Bob, and Charlie and then runs one round of the assisted
teleportation protocol.

The script:

1. Creates a `RegisterNet` with continuous-variable `Qumode` slots backed by
   `Gabs.jl`.
2. Prepares a random coherent input state, which is the state to be teleported.
3. Prepares the shared three-mode Gaussian resource used by the assisted
   protocol.
4. Lets Alice perform the Bell-like homodyne step and Charlie perform the
   assisting homodyne step.
5. Sends those classical measurement outcomes to Bob and applies the final
   displacement correction on Bob's mode.

At the end of the script, the example prints the initial Gaussian state and
Bob's final Gaussian state. They should be very similar, with the remaining
difference coming from finite squeezing in the shared resource.

The squeezing strength is controlled by the `RESOURCE_SQUEEZE` constant near the
top of `setup.jl`. Increasing it makes the teleportation closer to ideal.

## What QuantumSavory Features It Teaches

This example is also a compact tutorial for several low-level QuantumSavory
interfaces:

1. How to build a small network model out of `Register` nodes collected into a
   `RegisterNet`.
2. How to use continuous-variable slots with an explicit backend
   representation, here `Qumode` together with `GabsRepr(QuadBlockBasis)`.
3. How to initialize states and apply Gaussian symbolic operations with
   `initialize!` and `apply!`.
4. How to perform projective continuous-variable measurements through
   `project_traceout!(..., HomodyneMeasurement(...))`.
5. How to express classical communication inside a network simulation through
   `channel`, `Tag`, `messagebuffer`, and `query_wait`.
6. How to package a protocol as a callable struct together with a `@resumable`
   process that runs inside the `ConcurrentSim`-based simulator.
7. How to inspect the resulting backend state directly with `stateof` for
   simple sanity checks at the end of an example. This is an introspection tool,
   you should not use it to modify the state of the simulation as it provides
   god-like unphysical access.

Documentation:

- [The register interface, including `Register`, `RegisterNet`, and `project_traceout!`](https://qs.quantumsavory.org/dev/register_interface/)
- [The tagging and querying interface used for classical communication](https://qs.quantumsavory.org/dev/tag_query/)
- [The discrete-event simulation overview for `@resumable` protocols](https://qs.quantumsavory.org/dev/discreteeventsimulator/)
- [The full API page, including exported types such as `HomodyneMeasurement`](https://qs.quantumsavory.org/dev/API/)
