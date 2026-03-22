# [Quantum Systems, Subsystems, and Entanglement](@id quantum-systems)

Many quantum tutorials start with an ideal closed system: a few qubits, no
noise, and unitary gates only. That is useful for learning, but it is usually
not enough for realistic hardware modeling.

## Closed Systems Versus Open Systems

A closed quantum system evolves without outside interference. Real hardware is
rarely like that. It loses energy, dephases, and couples to uncontrolled parts
of the environment.

That is why QuantumSavory treats noise and time as first-class parts of the
model. If you care about memory lifetime, waiting time, or protocol latency,
you usually care about open-system behavior as well.

## More Than Ideal Qubits

Real platforms are not all the same kind of subsystem.

- some are well approximated as qubits
- some are naturally multi-level systems
- some are bosonic modes or continuous-variable systems

This matters because the right operations, observables, and efficient
simulation methods depend on the subsystem type. A model that is convenient for
one platform may be a poor fit for another.

QuantumSavory uses registers and slot properties to make those differences
explicit instead of hiding them behind one idealized subsystem model.

## Why Entanglement Matters

Entanglement is the key resource behind many distributed quantum tasks. It is
also one of the main reasons simulation becomes hard: once subsystems are
strongly correlated, you cannot always treat them independently.

For networking and distributed protocols, this matters constantly. Bell pairs,
multipartite states, storage slots, swaps, and fusion operations are all really
about creating, moving, or consuming entanglement across subsystems.

## Why This Background Helps In QuantumSavory

If you know whether your model is:

- mostly closed or strongly open,
- built from qubits or more general subsystems, and
- lightly or heavily entangled,

then you can make much better choices about properties, noise models, and
backends. That is the reason QuantumSavory exposes these concepts directly: it
helps you build a model that matches the hardware, instead of forcing the
hardware into one fixed abstraction.

## Where To Go Next

- Read [Properties](@ref) for how subsystem assumptions are attached to
  register slots.
- Read [Background Noise Processes](@ref) for how open-system effects are
  declared in the model.
- Read [Choosing a Backend and Modeling Tradeoffs](@ref modeling-tradeoffs) for
  the simulation consequences of these choices.
