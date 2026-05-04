The docs frame performance mainly as a backend and state-structure question,
not just a raw node-count question.

The biggest bottlenecks to expect are:

- leaving a restricted regime and falling back to a more general backend;
- creating large entangled clusters that defeat factorized storage;
- using dense wavefunction-style simulation where a specialized backend would
  have been enough;
- and adding physically richer subsystem models that require more expensive
  representations.

The main backend tradeoffs are:

- `CliffordRepr()` is usually the cheapest option for qubit stabilizer-style
  workloads with Pauli-like noise;
- `QuantumOpticsRepr()` is the most flexible built-in choice, but it has the
  least structural compression and will become expensive fastest in generic
  cases;
- `GabsRepr(...)` is the efficient choice for Gaussian continuous-variable
  models.

The register model helps because untouched or independent subsystems stay
factorized until interaction forces composition. That means cost often tracks
the size of the entangled clusters you actually create, not just the total
number of slots in the model.

So the practical guidance is:

1. start with the cheapest backend that still preserves the effect you care
   about;
2. validate on a smaller instance with a more general backend when needed;
3. expect major cost jumps when your model leaves the assumptions of a
   restricted formalism.

