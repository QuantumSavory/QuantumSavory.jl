# [Choosing a Backend and Modeling Tradeoffs](@id modeling-tradeoffs)

QuantumSavory separates symbolic descriptions from numerical backends because no
single simulator is the right tool for every problem.

The practical question is not "which backend is best in general?", but "which
backend preserves the physics I care about at an acceptable computational
cost?"

## Two Important Tradeoffs

There are two largely independent choices in quantum simulation:

- how to represent classical uncertainty and stochastic effects, and
- how to represent quantum correlations and entanglement.

Dense state vectors and density matrices are the most direct descriptions, but
they scale poorly. Specialized formalisms become much cheaper by exploiting
structure in the state, the operations, or the noise model.

## Backend Choices In QuantumSavory

### `QuantumClifford`

Use `QuantumClifford` when your model is close to stabilizer dynamics:

- qubit-based systems,
- Clifford gates and Pauli measurements,
- Pauli-style noise models or approximations, and
- large simulations where speed matters.

This is usually the fastest option for repeater-style and error-correction-like
workflows that stay near the stabilizer regime.

### `QuantumOptics`

Use `QuantumOptics` when you need a more general wavefunction-style description:

- non-Clifford dynamics,
- smaller systems where flexibility matters more than scale, or
- a reference calculation against which to compare faster approximations.

This is the most general built-in path, but it pays for that generality with
exponential scaling in the generic case.

### `Gabs`

Use `Gabs` when the system is naturally Gaussian:

- bosonic modes,
- Gaussian states and Gaussian operations, and
- optical or continuous-variable models that remain in the Gaussian regime.

For those models, Gaussian simulation can be dramatically cheaper than a
general wavefunction treatment.

## Why The Symbolic Frontend Matters

The symbolic frontend lets you describe the intended state or operation first,
without immediately committing to a specific numerical representation. That is
what makes it possible to compare backends without rewriting the whole model.

## Practical Guidance

- Start with the cheapest backend that still captures the effect you care about.
- Use a more general backend to validate an approximation on smaller instances.
- Prefer restricted formalisms when the physics genuinely fits them.
- Remember that different subsystems or scenarios may call for different
  modeling choices.

## Future Direction

Tensor-network and other reduced-complexity backends fit naturally into this
architecture, but they are not yet first-class options in QuantumSavory.

## Where To Go Next

- Read [Backend Simulators](@ref backend) for the current backend overview.
- Read [Properties](@ref) and [Background Noise Processes](@ref) for how
  subsystem types and background processes affect the model.
- Read [Symbolic Expressions](@ref) for the frontend side of the abstraction.
