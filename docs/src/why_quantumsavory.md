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


## Comparison To Other Tools

Issue [#21](https://github.com/QuantumSavory/QuantumSavory.jl/issues/21)
asked for a short orientation against other quantum-network simulators.
The tools below are not ranked. They optimize for different questions,
and several of them can be the better choice for a given study.

- **NetSquid** is a discrete-event Python simulator for quantum networks
  and devices, with interchangeable state representations and detailed
  timing. It is widely used for hardware-faithful network studies. Access
  is through a registration/license rather than a fully open-source
  tree ([paper](https://www.nature.com/articles/s42005-021-00647-8)).
- **QuISP** is an open-source C++ / OMNeT++ discrete-event simulator
  aimed at *large* networks. It tracks a compact error model of each
  qubit rather than a full quantum state, which is what makes city-scale
  topologies tractable.
- **QuNetSim** (the name "QuEntSim" in older notes refers to this
  project) is a Python library for writing network-layer protocols
  quickly. It favors a small API over a high-fidelity physical layer.
- **SimulaQron** is a distributed *emulator* for application development.
  It is meant to run on several classical machines as if they were
  quantum nodes, not to provide a physically timed hardware model.
- **ReQuSim** focuses on faithfully simulating first-generation quantum
  repeaters, including the noise and timing that dominate that regime.

QuantumSavory sits in a different place on that map: one register
interface, a symbolic frontend, several numerical backends (including
Clifford and wavefunction-style representations), and a metadata plane
for LOCC-style protocols. The usual reason to pick it is codesign work
that has to move between a fast restricted model and a more general one
without rewriting the protocol layer. If you need OMNeT++-scale classical
networking, a license-gated NetSquid stack, or a multi-machine
application emulator, the tools above are built for those jobs.

## Where To Go Next

- Read [Architecture and Mental Model](@ref architecture) for how these ideas
  are reflected in the package structure.
- Read [Choosing a Backend and Modeling Tradeoffs](@ref modeling-tradeoffs) for
  the simulation-side consequences.
- The comparison section above is the short answer to "how does this
  relate to NetSquid, QuISP, QuNetSim, SimulaQron, and ReQuSim?"
