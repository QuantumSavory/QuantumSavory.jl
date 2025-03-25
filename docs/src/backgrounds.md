# Background Noise Processes

For each subsystem (slot in the register), you also specify what background processes and noise parameters describe it.
For instance, it could be a [`T1Decay`](@ref) or [`T2Dephasing`](@ref) process, or a coherent error, or a non-Markovian bath.
It is supported by all backends (but maybe with twirling, e.g. to support `T1Decay` in a Clifford simulation).

Currently we implement:

```@example subtypes
using QuantumSavory # hide
using InteractiveUtils # hide
subtypes(QuantumSavory.AbstractBackground)
```

If you want to introspect these noise processes, you can use the [`paulinoise`](@ref), [`krausops`](@ref), and [`lindbladop`](@ref) functions.