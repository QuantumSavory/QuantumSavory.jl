# Explanations

This section is for understanding how QuantumSavory is put together and why it
works the way it does.

If you are new to the package, first go through the [Manual](@ref manual) for a
small hands-on example. Then come back here for the conceptual model.

## What Lives Here

Explanation pages answer questions such as:

- What is a `Register`, and how does a `RegisterNet` fit into a simulation?
- Why does QuantumSavory separate symbolic descriptions from numerical
  backends?
- How are background noise processes and time handled?
- How are classical control, metadata tags, and protocols composed?
- When should one backend or modeling approach be preferred over another?

## Suggested Reading Order

1. [Architecture and Mental Model](@ref architecture)
2. [Why QuantumSavory Exists](@ref why-quantumsavory)
3. [Quantum Systems, Subsystems, and Entanglement](@ref quantum-systems)
4. [Choosing a Backend and Modeling Tradeoffs](@ref modeling-tradeoffs)
5. [Metadata and Protocol Composition](@ref metadata-plane)
6. [Properties](@ref)
7. [Background Noise Processes](@ref)
8. [Symbolic Expressions](@ref)
9. [Discrete Event Simulator](@ref sim)
10. [Visualizations](@ref Visualizations)

## Relationship To Other Sections

- [Tutorials](@ref) are for guided, hands-on learning of a small feature.
- [How-To Guides](@ref) are for accomplishing concrete tasks.
- [References](@ref) are for looking up precise APIs and module contents.
