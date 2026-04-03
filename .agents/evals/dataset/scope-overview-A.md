QuantumSavory is a multi-formalism simulator for noisy quantum communication
and computation hardware. Its main job is to let you keep one high-level model
while changing how that model is simulated.

The core idea is to separate:

- symbolic descriptions of states, operations, observables, and protocol inputs;
- numerical backends such as `QuantumClifford`, `QuantumOptics`, or `Gabs`;
- the register model for heterogeneous hardware and background noise; and
- discrete-event protocol logic for waiting, messaging, retries, and resource
  contention.

It is a good fit when you care about several layers at once:

- hardware noise and time-dependent effects;
- heterogeneous subsystems such as qubits and bosonic modes;
- classical control around the quantum dynamics;
- reusable networking components such as entanglers, swappers, trackers, or
  switch controllers; and
- comparing a cheaper approximation against a more general backend without
  rewriting the whole simulation.

It is especially well matched to digital-twin style work, repeater and
networking simulations, and studies where the hard part is keeping protocol
logic, hardware assumptions, and backend choice consistent as the model
evolves.

It is probably the wrong tool when you only need one narrow simulator directly:

- if the whole model is just a stabilizer calculation, `QuantumClifford` may be
  simpler;
- if you only need a small general wavefunction calculation, going directly to
  `QuantumOptics` may be simpler;
- if you do not need protocol timing, metadata, channels, or reusable building
  blocks, the full stack may be more than you need.

Good next reads are "Architecture and Mental Model", "Why QuantumSavory
Exists", and "Choosing a Backend and Modeling Tradeoffs".
