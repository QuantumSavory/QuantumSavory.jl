# [Comparison to Other Tools](@id comparison)

Issue [#21](https://github.com/QuantumSavory/QuantumSavory.jl/issues/21) asked for an explicit comparison against the simulators people actually evaluate QuantumSavory next to. This page is that comparison. It is not a ranking.

The useful question is usually not "which package is best" but "which layer of the problem does this package own". The tools below overlap on "quantum networks" and then diverge hard on language, state representation, scale, and whether you are writing a physics model or a network stack.

## How to read the table

| | QuantumSavory.jl | NetSquid | QuISP | QuNetSim | SimulaQron | ReQuSim |
|---|---|---|---|---|---|---|
| Language | Julia | Python | C++ (OMNeT++) | Python | Python | Python |
| Primary job | Hardware/protocol codesign with interchangeable backends | Discrete-event quantum network simulation at the physical/link layer | Large-scale quantum *internet* protocol stacks | Teaching and high-level network experiments | Application-level programming against a simulated quantum internet | Faithful Monte Carlo of near-term **repeaters** |
| State model | Symbolic frontend + pluggable numerical backends (stabilizer, wavefunction, …) | Multiple representations (kets, density matrices, stabilizers, …) | Error tracking rather than full states | Delegates quantum objects to a backend | Simulated qubits at application API | Event-driven Monte Carlo with time-dependent noise |
| Timing | Discrete-event (`ConcurrentSim`) plus register/channel delays | Discrete-event | Discrete-event (OMNeT++) | Simplified network time | Real classical network delays between processes | Discrete-event |
| Typical user | Someone changing hardware assumptions *and* protocol logic in one model | Someone assembling NetSquid components into a node/link experiment | Someone studying routing, congestion, and stack design at internet scale | Students and prototypes | Application developers | Repeater-protocol / QKD rate studies |

## NetSquid

[NetSquid](https://netsquid.org/) (QuTech) is the Python discrete-event simulator most papers mean when they say "we simulated a quantum network". Nodes, components, quantum and classical channels, and protocols are first-class. It has several quantum-state formalisms and a large published-model ecosystem.

Stay with NetSquid when the experiment is a NetSquid component graph and you want that community's models. Reach for QuantumSavory when the bottleneck is *rewriting* the same protocol every time the hardware model or backend changes — the [why QuantumSavory exists](@ref why-quantumsavory) page is the longer version of that claim.

## QuISP

[QuISP](https://github.com/sfc-aqua/quisp) (Quantum Internet Simulation Package) sits on OMNeT++ and is aimed at the *network* of a quantum internet: protocol stacks, error tracking instead of full Hilbert-space states, and scales that full-state simulators do not reach.

Use QuISP for internet-scale protocol and traffic questions. Use QuantumSavory when you still need an actual quantum state (or several alternative representations of one) inside a register, a channel, or a purification circuit.

## QuNetSim

[QuNetSim](https://github.com/tqsd/QuNetSim) (the name that shows up as "quentsim" in [#21](https://github.com/QuantumSavory/QuantumSavory.jl/issues/21)) is a Python teaching/prototyping layer: hosts, connections, and a small set of network operations, with quantum objects handed to a backend.

It is the right first tool for a course or a one-off protocol sketch. It is not trying to be a hardware digital twin, and QuantumSavory is not trying to be a 50-line teaching API.

## SimulaQron

[SimulaQron](http://www.simulaqron.org/) simulates a quantum internet *from the application side*. You write software as if talking to real quantum-network nodes; classical messages can travel on a real network so the *timing* of the classical plane is realistic. It does not try to be a physics-level hardware model.

Pick SimulaQron to develop applications against a fake quantum internet. Pick QuantumSavory to ask whether a given hardware and protocol model still works after you change the noise, the subsystem type, or the backend.

## ReQuSim

[ReQuSim](https://github.com/jwallnoefer/requsim) is a Python Monte Carlo platform built specifically for **quantum repeaters**: time-dependent memory noise, loss, purification vs extra stations, and numerical key rates when the algebra is no longer tractable ([PRX Quantum 5, 010351](https://doi.org/10.1103/PRXQuantum.5.010351)).

If the paper is "what rate does this near-term repeater chain actually get", ReQuSim is purpose-built for that. QuantumSavory's repeater how-tos cover similar physics but as part of a general register/protocol/backend stack rather than as a repeater-only Monte Carlo.

## What QuantumSavory is *not* claiming

- It is not a drop-in NetSquid replacement, and it does not have NetSquid's volume of published component models.
- It is not an OMNeT++-scale internet simulator (that is QuISP).
- It is not the smallest API for a quantum-networks homework set (that is QuNetSim).
- It is not an application-facing quantum-internet runtime (that is SimulaQron).
- It is not a repeater-only Monte Carlo (that is ReQuSim).

The distinctive bet is documented in [Why QuantumSavory Exists](@ref why-quantumsavory) and [Choosing a Backend and Modeling Tradeoffs](@ref modeling-tradeoffs): one model, several backends, registers that are not only ideal qubits, and protocol components that coordinate through tags and messages instead of through rewrite-the-glue.

## See also

- [Why QuantumSavory Exists](@ref why-quantumsavory)
- [Architecture and Mental Model](@ref architecture)
- [Choosing a Backend and Modeling Tradeoffs](@ref modeling-tradeoffs)
