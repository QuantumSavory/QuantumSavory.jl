# Large Grid Network with Classical Synchronization of Messages and only "Local Knowledge" Control

Our goal is to simply entangle two specific clients on a grid network.
All nodes of the network are capable of running nearest-neighbor entanglement generation, swaps, potentially cutoff-time deletion of old qubits, all of the classical communication machinery to distribute the necessary metadata among neighbors.

This is very much a simple **local knowledge and NO global controller** setup for network control.

This example visualizes a quantum network attempting to distribute between the Alice and Bob user pair located on the diagonal of a grid topology.
Asynchronous messaging and queries are used for classical communication of entanglement information between nodes using protocols like [`EntanglementTracker`](@ref) and [`SwapperProt`](@ref).
Link-level-entanglement is generated between all the horizontal and vertical neighbors using an entanglement generation protocol called [`EntanglerProt`](@ref).
As an entanglement link is established between the end users, it is consumed by a protocol named [`EntanglementConsumer`](@ref) which records the fidelity and time of consumption of the pair.
The qubits that remain unused beyond their `retention_time` are discarded by the [`CutoffProt`](@ref)


This module provides two ways of running the simulation:

- [`SwapperProt`](@ref) and [`CutoffProt`](@ref) in an asynchronous manner where they run independently and all the classical information about the quantum states is reconciled using asynchronous messages sent to the tracker.

- [`SwapperProt`](@ref) does not use qubits that are too old (and independently expected to be thrown away by the [`CutoffProt`](@ref)), by checking their `agelimit` parameter passed to it during initialization. Here, there are no outgoing messages from the [`CutoffProt`](@ref).