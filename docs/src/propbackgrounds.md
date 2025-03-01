# [Properties and Backgrounds](@id Properties-and-Backgrounds)

When creating a new registers, you can specify what type of physical system it will contain in each slot,
e.g. a [`Qubit`](@ref) or a qudit or a harmonic oscillator or a propagating wave packet.

For each subsystem (slot in the register), you also specify what background processes and noise parameters describe it.
For instance, it could be a [`T1Decay`](@ref) or [`T2Dephasing`](@ref) process, or a coherent error, or a non-Markovian bath.