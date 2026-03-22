# [Metadata and Protocol Composition](@id metadata-plane)

QuantumSavory protocols often need to coordinate without being tightly coupled
to one another. Instead of passing explicit handles everywhere, the library
supports a metadata layer built around tags, queries, and message buffers.

## Why This Exists

In a realistic network simulation, one protocol may create an entangled pair,
another may wait for it, and a third may consume it later. Hard-wiring these
components together makes reuse difficult. QuantumSavory instead lets protocols
communicate through structured metadata attached to resources.

## The Core Idea

- tags attach classical metadata to register slots or message buffers,
- queries search for matching metadata, and
- protocols wait on those changes inside the discrete-event simulator.

This means protocols can coordinate by publishing and consuming facts such as:

- which remote node a qubit is entangled with,
- whether a purification or swap succeeded,
- whether a message for a given protocol stage has arrived, or
- whether a resource is ready for a follow-up step.

## Register Metadata and Message Buffers

The same mental model is used in two places:

- on register slots, where tags describe quantum resources and their history,
- on message buffers, where tags act as protocol messages waiting to be
  consumed.

Using one abstraction for both makes protocol composition simpler. The same
query tools can be used to discover resources, wait for messages, or clear
consumed state.

## Why It Helps Composition

This design lets independently written protocols interoperate as long as they
agree on the meaning of shared tags and messages. That keeps higher-level
protocols from needing to know the internal control flow of lower-level ones.

## Where To Go Next

- Read [Discrete Event Simulator](@ref sim) for the execution model around
  waiting and scheduling.
- Read [Tagging and Querying](tag_query.md) for the detailed API reference.
- Read [References](@ref) when you need exact signatures.
