# [Why QuantumSavory Exists](@id why-quantumsavory)

Quantum hardware design is a codesign problem. Device noise, subsystem type,
protocol logic, and classical control all affect each other. If those layers
are modeled separately, it becomes slow to answer simple questions such as:

- does this protocol still work with a more realistic hardware model?
- is this approximation still good enough at the scale I care about?
- can I change the backend or noise model without rewriting the whole study?

## What Usually Slows Work Down

Three kinds of friction show up again and again:

- the math changes when the right simulator changes
- the hardware model changes when the physical subsystem changes
- the protocol logic gets tied to bespoke glue code for timing and messaging

That is bad for productivity. Instead of changing one assumption and rerunning
the study, you end up rewriting large parts of the model.

## What QuantumSavory Tries To Fix

QuantumSavory exists to reduce that rewriting.

- the symbolic frontend lets you describe states, operations, and observables
  once
- interchangeable backends let the same model run with different numerical
  methods
- registers and properties let you describe more than ideal qubits
- discrete-event execution and the metadata plane let protocol components
  coordinate without being hard-wired to each other

## What That Approach Changes In Practice

- the same protocol logic can be reused while you switch between a fast
  restricted model and a more general one
- the same workflow can cover more than ideal qubits, including memories,
  bosonic modes, continuous-variable models, and other heterogeneous
  subsystems when the chosen backend supports them
- common network tasks can be assembled from reusable protocol components,
  tags, and message buffers instead of rebuilt as one-off control code
- noise and timing assumptions can be changed at the model level without
  manually re-encoding them in each backend's mathematical language

## Why That Is Useful

This design makes it easier to build digital twins step by step. You can start
with a simple model, add more realistic subsystem assumptions, switch to a
faster or more accurate backend, and keep the same overall simulation
structure.

In short, QuantumSavory is meant to save time when the hard part of the work is
not one gate or one formula, but keeping hardware assumptions, protocol logic,
noise, and classical control consistent as the study evolves.

## Where To Go Next

- Read [Architecture and Mental Model](@ref architecture) for how these ideas
  are reflected in the package structure.
- Read [Choosing a Backend and Modeling Tradeoffs](@ref modeling-tradeoffs) for
  the simulation-side consequences.
