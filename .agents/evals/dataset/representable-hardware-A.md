The core modeling unit is a `Register`, and a network is a `RegisterNet`.

That means a node is usually represented as a register with one or more slots.
Each slot can carry:

- a subsystem type such as a qubit-like or bosonic-mode-like system;
- a preferred numerical representation;
- and an optional background process such as dephasing or damping.

This is designed for heterogeneous hardware. A single node can mix different
subsystems instead of flattening everything into ideal qubits.

For example, the docs explicitly show hybrid registers such as:

```julia
Register(
    [Qubit(), Qumode()],
    [CliffordRepr(), QuantumOpticsRepr()],
)
```

So memories, communication qubits, optical modes, and similar components are
modeled through slot types, representations, and background processes rather
than through a large catalog of fixed node classes.

For entanglement resources, you have several options:

- initialize symbolic states directly;
- use reusable state families from `StatesZoo`, such as the Barrett-Kok and
  Genqo-inspired families;
- generate resources dynamically through protocols such as `EntanglerProt`.

The high-level point is that the package supports both hand-built symbolic
resources and reusable physically motivated state families inside the same
register/network model.

