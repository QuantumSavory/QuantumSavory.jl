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
- When is NetSquid, QuISP, or another network simulator a better fit?
- How are background noise processes and time handled?
- How does the symbolic frontend stay backend-agnostic without hiding modeling
  limits?
- How are classical control, metadata tags, and protocols composed?
- When should one backend or modeling approach be preferred over another?

## Suggested Reading Order

1. [Architecture and Mental Model](@ref architecture)
2. [Why QuantumSavory Exists](@ref why-quantumsavory)
3. [Comparison to Other Tools](@ref comparison-to-other-tools)
4. [Restricted Formalisms and Efficient Simulation](@ref
   restricted-formalisms)
5. [Choosing a Backend and Modeling Tradeoffs](@ref modeling-tradeoffs)
6. [Modeling Registers, Factorization, and Time](@ref
   modeling-registers-time)
7. [Register Networks](@ref register-networks)
8. [Symbolic Frontend](@ref symbolic-frontend)
9. [Metadata and Protocol Composition](@ref metadata-plane)
10. [Classical Messaging and Buffers](@ref classical-messaging)
11. [Zoos as Composable Building Blocks](@ref zoos-building-blocks)
12. [Properties](@ref)
13. [Background Noise Processes](@ref)
14. [Discrete Event Simulator](@ref sim)

## Relationship To Other Sections

- [Tutorials](@ref) are for guided, hands-on learning of a small feature.
- [How-To Guides](@ref) are for accomplishing concrete tasks.
- [References](@ref) are for looking up precise APIs and module contents.
