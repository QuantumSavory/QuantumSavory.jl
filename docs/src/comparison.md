# [Comparison to Other Tools](@id comparison-to-other-tools)

QuantumSavory is one of several simulators people use for quantum networks.
They overlap, but they were built for different jobs. This page is a map of
that overlap for the tools named most often next to QuantumSavory:
NetSquid, QuISP, QuNetSim, SimulaQron, and ReQuSim.

It is not a benchmark and it is not a ranking. If a tool already matches the
layer you need, use it.

## What question each tool is answering

| Tool | Typical question | Usual layer |
|:--|:--|:--|
| **NetSquid** | How does this hardware model behave, with timing, under a network stack? | physical through application, discrete-event, Python |
| **QuISP** | How do repeater / internet protocols behave at large node counts? | network protocols at scale, OMNeT++ / C++, error-model tracking |
| **QuNetSim** | Can I sketch a network-layer protocol without building a hardware model? | network / application, educational Python |
| **SimulaQron** | Can I write an application as if a quantum internet already existed? | application development against a virtual network |
| **ReQuSim** | What rates and fidelities does this first-generation repeater chain produce? | specialized repeater-chain simulation |
| **QuantumSavory** | Can I keep one model while I change backends, noise, and protocol glue? | registers + symbolic frontend + discrete-event protocols, Julia |

Several other simulators exist (SeQUeNCe, SimQN, QKDNetSim, and others). They
are omitted here only because this page tracks the list in the original
request, not because they are unimportant.

## NetSquid

[NetSquid](https://netsquid.org/) is a discrete-event quantum network
simulator from QuTech. It is the closest well-known analogue to QuantumSavory
on the "network plus hardware plus timing" axis. Components, connections, and
protocols are first-class. Physical-layer models (photons, detectors, memory
noise) are a large part of its value.

Choose NetSquid when the study is a detailed Python hardware stack and you
want the ecosystem around it (NetQASM, published models, a large user base).
Choose QuantumSavory when the same study also needs interchangeable numerical
backends (Clifford vs dense kets vs Gaussian / qumode), a symbolic description
of states and observables, or Julia-native protocol composition through tags
and message buffers.

NetSquid is not a drop-in replacement for that last part: it does not try to
be a multi-formalism symbolic frontend. QuantumSavory is not a drop-in
replacement for NetSquid's catalog of photonic hardware components.

## QuISP

[QuISP](https://github.com/sfc-aqua/quisp) (Quantum Internet Simulation
Package) sits on OMNeT++ and is written for *internet-scale* protocol work.
Its usual trick is to track an error model of qubits rather than a full
joint quantum state, so the simulation can grow to many networks and many
nodes.

Choose QuISP when the object of study is a large internetwork, RuleSet-style
protocol architecture, or the interaction of many independent networks.
Choose QuantumSavory when you need the actual quantum state (or a
backend-specific representation of it) inside registers, including
entanglement that you will `observable` or visualize, and when the network
is small enough that that state tracking is acceptable.

QuISP's scale is the point. QuantumSavory's multi-backend register is the
point. They optimize opposite ends of the "how much quantum state do I keep"
tradeoff.

## QuNetSim

[QuNetSim](https://tqsd.github.io/QuNetSim/) is a Python framework for
network- and application-layer protocols: teleportation, EPR distribution,
GHZ, routing sketches. It is deliberately easier than a hardware-faithful
simulator. The authors describe it as educational; it does not try to be a
full physical-layer engine.

The issue that requested this page listed it as "quentsim". That is the same
tool.

Choose QuNetSim to teach or to prototype a protocol at the "hosts send qubits
and classical packets" level. Choose QuantumSavory when the same protocol has
to sit on registers with backgrounds, backend choice, and discrete-event
locks / tags.

## SimulaQron

[SimulaQron](https://softwarequtech.github.io/SimulaQron/_build/html/) is an
application-level quantum internet simulator. The original use is to write
software against a virtual quantum network, including running pieces on
separate classical computers, without first having the hardware.

Choose SimulaQron when the artifact is an application (or a CQC-style
interface) that should later run on a real or more detailed stack. Choose
QuantumSavory when the artifact is a model of the hardware and the protocols
that move entanglement around, including noise and time.

SimulaQron can be combined with more detailed simulators for the network
under the application. That combined workflow is not what QuantumSavory is
for either: QuantumSavory *is* the network-and-hardware model.

## ReQuSim

[ReQuSim](https://github.com/jwallnoefer/requsim) is a Python Monte Carlo
simulator for quantum repeater chains (Wallnöfer et al., PRX Quantum 2024).
The value is a faithful, relatively narrow model of repeater strategies with
time-dependent memory noise, not a general register-network toolkit.

Choose ReQuSim when the paper is about near-term repeater performance and you
want a tool that already speaks that dialect. Choose QuantumSavory when the same
repeater is one example among others, or when you need to swap Clifford vs
ket backends, attach custom tags, or compose ProtocolZoo components around
the chain.

QuantumSavory's own first-generation repeater how-tos cover a similar
physical story with a different architecture (registers, protocols, plots).
They do not make ReQuSim redundant for people who already live in that
codebase.

## Where QuantumSavory is a better fit

These are the jobs the rest of this documentation is built around:

- describe a state, gate, or observable once and lower it onto
  `QuantumOpticsRepr`, `CliffordRepr`, Gaussian / qumode backends, or
  `QuantumMCRepr`;
- mix qubits and qumodes (and other slot traits) in one node;
- declare background noise on slots and let time evolution be part of the
  register, not a manual rewrite per backend;
- compose protocols through tags, queries, and message buffers rather than
  a fixed object graph of peer handles;
- reuse `ProtocolZoo` / `CircuitZoo` / `StatesZoo` pieces in a larger
  discrete-event simulation.

That list is the same productivity argument as
[Why QuantumSavory Exists](@ref why-quantumsavory). The comparison above is
the negative space: if you do not need those, another tool may be less work.

## Where another tool is a better fit

- **NetSquid**, for a mature Python physical-layer catalog and a large
  published-model ecosystem.
- **QuISP**, for many-node internetwork protocol studies where keeping every
  joint state would be the wrong cost model.
- **QuNetSim**, for teaching and for high-level protocol sketches.
- **SimulaQron**, for application code against a virtual quantum internet.
- **ReQuSim**, for a dedicated 1G repeater-chain study.

QuantumSavory will not grow a NetSquid-sized photonic component library just
to close that gap, and it will not drop register state tracking just to match
QuISP's scale. Those are different products.

## Where to go next

- [Why QuantumSavory Exists](@ref why-quantumsavory) for the codesign
  problem this package is aimed at.
- [Architecture and Mental Model](@ref architecture) for how registers,
  backends, and protocols sit together.
- [Choosing a Backend and Modeling Tradeoffs](@ref modeling-tradeoffs) for
  the QuantumSavory-internal analogue of "which simulator".
