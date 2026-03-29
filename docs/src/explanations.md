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
- How does the symbolic frontend stay backend-agnostic without hiding modeling
  limits?
- How are classical control, metadata tags, and protocols composed?
- When should one backend or modeling approach be preferred over another?

## Suggested Reading Order

1. [Architecture and Mental Model](@ref architecture)
2. [Why QuantumSavory Exists](@ref why-quantumsavory)
3. [Restricted Formalisms and Efficient Simulation](@ref
   restricted-formalisms)
4. [Choosing a Backend and Modeling Tradeoffs](@ref modeling-tradeoffs)
5. [Modeling Registers, Factorization, and Time](@ref
   modeling-registers-time)
6. [Symbolic Frontend](@ref symbolic-frontend)
7. [Metadata and Protocol Composition](@ref metadata-plane)
8. [Classical Messaging and Buffers](@ref classical-messaging)
9. [Zoos as Composable Building Blocks](@ref zoos-building-blocks)
10. [Properties](@ref)
11. [Background Noise Processes](@ref)
12. [Discrete Event Simulator](@ref sim)

## Relationship To Other Sections

- [Tutorials](@ref) are for guided, hands-on learning of a small feature.
- [How-To Guides](@ref) are for accomplishing concrete tasks.
- [References](@ref) are for looking up precise APIs and module contents.
