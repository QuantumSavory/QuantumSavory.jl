Start with `CliffordRepr()`, which selects the `QuantumClifford` stabilizer
backend.

That is the documented best fit when all or most of these are true:

- the subsystems are qubits;
- the dynamics stay near the Clifford regime;
- the important noise is Pauli-like or can be approximated that way; and
- simulation scale matters.

This is usually the right first backend for repeater-style workloads because it
gets you the structural compression of tableau-based stabilizer simulation
without changing the surrounding register or protocol model.

Switch to a more general backend such as `QuantumOpticsRepr()` when:

- you add non-Clifford dynamics that actually matter to the question;
- the noise model is no longer well captured by the stabilizer approximation;
- or you want a smaller reference calculation to validate the approximation.

The intended workflow is:

1. build the model once using registers, symbolic operators, and protocols;
2. run the cheapest backend that preserves the effect you care about;
3. check a smaller instance with a more general backend if needed.

One practical caveat: if you do not specify a representation explicitly, the
docs say `Qubit()` currently defaults to `QuantumOpticsRepr()`. If backend
choice matters, set it explicitly rather than relying on the default.

