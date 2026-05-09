# [Zoos as Composable Building Blocks](@id zoos-building-blocks)

QuantumSavory ships three curated collections of reusable components:

- `StatesZoo` for parameterized quantum states,
- `CircuitZoo` for reusable quantum circuits,
- `ProtocolZoo` for reusable discrete-event protocol components.

These "Zoos" provide convenience, remove boilerplate, and showcase the ease of composability in this simulation toolkit.

## Why The Zoos Matter

If the framework is well factored, common states, circuits, and protocols
should be expressible once and then reused in many simulations. The Zoos are
that reuse layer.

They reduce work in three ways:

- they remove repeated low-level implementation of common building blocks;
- they expose parameters that users actually want to sweep;
- they let larger simulations be assembled from components that already speak
  the same register, symbolic, and metadata conventions.

The Zoos reuse the same abstractions available to user-written code -- they are not special and a user can use QuantumSavory's public API to produce similar abstractions of their own.

## `StatesZoo`

`StatesZoo` provides symbolic or symbolic-like descriptions of useful resource
states, especially realistic surrogate states for networking hardware.

This is useful when the user cares about the output of a physical process, but
does not want to rebuild the microscopic derivation every time. Instead of
re-implementing a noisy entanglement source from scratch, the user selects a
parameterized state family and initializes registers from it.

## `CircuitZoo`

`CircuitZoo` provides reusable quantum circuits such as swapping, purification,
and fusion routines.

These are small building blocks, but they matter because they encode common
multi-qubit logic once and expose it through a stable callable interface. A
protocol can then depend on a circuit by intent rather than inlining a long
sequence of gates each time.

## `ProtocolZoo`

`ProtocolZoo` provides reusable control-plane components such as entanglers,
swappers, trackers, consumers, and switch-style controllers.

These are full discrete-event processes packaged as `AbstractProtocol`
implementations. They compose through the metadata and messaging interfaces
rather than by requiring direct knowledge of each other's internal state.

That is what makes them a practical building-block layer instead of a bag of
isolated examples.

## Why The Three Zoos Fit Together

The three Zoos live at different layers, but they line up:

- a protocol can generate or consume a state from `StatesZoo`,
- a protocol can call a circuit from `CircuitZoo`,
- and multiple protocols from `ProtocolZoo` can coordinate through shared tags
  and message buffers.

Because they share the same symbolic frontend and register API, users can swap
one piece without rewriting the rest of the simulation.

## What The Zoos Are Not

The Zoos are not meant to replace user-written models. They are meant to
provide:

- standard starting points,
- parameterized reference implementations,
- and interoperable components that reduce glue code.

When a needed component does not exist yet, the same APIs remain available for
the user to define their own state, circuit, or protocol in the same style.

## Where To Go Next

- Read [Predefined Models of Quantum States](API_StatesZoo.md) for the current
  state families.
- Read [Predefined Quantum Circuits](API_CircuitZoo.md) for the reusable
  circuit layer.
- Read [Predefined Networking Protocols](API_ProtocolZoo.md) for the reusable
  protocol layer.
