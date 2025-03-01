# First Generation Quantum Repeater - A Simpler Implementation

!!! info "TODO Unfinished"
    This page is unfinished!

Compared to [the lower-level implementation `firstgenrepeater`](@ref First-Generation-Quantum-Repeater), which does not use convenient high-level abstractions, the code here (`firstgenrepeater_v2`) is drastically simpler. It is little more than direct calls to two pre-defined protocols available in [`QuantumSavory.ProtocolZoo`](@ref "Predefined Networking Protocols"): [`QuantumSavory.ProtocolZoo.EntanglerProt`](@ref) for probabilistic generation of nearest-neighbor entanglement and [`QuantumSavory.ProtocolZoo.SwapperProt`](@ref) for entanglement swapping, as well as [`QuantumSavory.ProtocolZoo.EntanglementTracker`](@ref) to keep track of all classical metadata and messaging necessary for the control of the network.

It is instructive to compare this simple-to-use setup with the much lengthier but equivalent implementation in [`firstgenrepeater`](@ref First-Generation-Quantum-Repeater), especially if one wants to develop reusable protocols of their own.

The source code is in the [`examples/firstgenrepeater_v2`](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/firstgenrepeater_v2) folder.