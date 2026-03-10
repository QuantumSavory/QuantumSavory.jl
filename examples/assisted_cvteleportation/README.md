# Quantum Teleportation with Gaussian States

Implementation of the assisted continuous variable (CV) quantum teleportation protocol introduced in https://arxiv.org/abs/quant-ph/0604027, using [Gabs.jl](https://github.com/QuantumSavory/Gabs.jl) as the numerical backend for Gaussian phase space dynamics and measurements. Here, Alice and Charlie perform homodyne measurements on a shared tripartite entangled resource to enable Bob to reconstruct an input state via displacement.

The `setup.jl` file implements the base functionality and runs the basic protocol, which is titled as `AssistedTeleport`. 