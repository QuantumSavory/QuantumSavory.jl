# [Backend Simulators](@id backend)

This page is the backend-focused companion to
[Choosing a Backend and Modeling Tradeoffs](@ref modeling-tradeoffs). It names
the current built-in backend families, the representation types that select
them, and the interface points used when attaching a new backend.

## Built-In Backend Families

### `QuantumClifford`

`CliffordRepr()` selects the stabilizer backend built on
`QuantumClifford.MixedDestabilizer`.

Use it when all of the following are approximately true:

- the modeled subsystems are qubits,
- the protocol stays near Clifford dynamics,
- the important noise can be represented as Pauli-like noise, and
- simulation scale matters more than generality.

This is the most specific built-in backend. In exchange for that restriction,
it is usually the cheapest option for repeater-style and stabilizer-native
network models.

### `QuantumOptics`

`QuantumOpticsRepr()` selects the general `QuantumOptics` backend, and
`QuantumMCRepr()` uses the same symbolic lowering path with a Monte Carlo style
state representation.

Use this family when:

- you need general qubit operations beyond the stabilizer regime,
- you need explicit ket or operator style simulation,
- you want one backend that can handle both qubits and bosonic modes, or
- you are validating a cheaper approximation on smaller systems.

This is the most flexible built-in path, but it also has the least structural
compression.

### `Gabs`

`GabsRepr(...)` selects the Gaussian backend from `Gabs`.

Use it when:

- the modeled subsystems are bosonic modes,
- the state stays in the Gaussian regime,
- the operations are Gaussian, and
- homodyne-style continuous-variable measurements are central to the model.

This is the right backend for continuous-variable models that would be awkward
or expensive to force into a generic wavefunction description.

## Choosing Precisely

The three built-in families answer different needs:

- `CliffordRepr()` for large qubit stabilizer workloads.
- `QuantumOpticsRepr()` for general qubit or mode simulations when flexibility
  matters more than asymptotic speed.
- `GabsRepr(...)` for Gaussian continuous-variable simulations.

If you are not sure which one to start with, the safest workflow is:

1. choose the cheapest backend that preserves the effect you care about;
2. validate that modeling choice on a smaller instance with a more general
   backend if needed.

## How Backend Selection Enters A Model

A register can specify representations slot by slot:

```julia
reg = Register(
    [Qubit(), Qumode()],
    [QuantumOpticsRepr(), GabsRepr(QuadBlockBasis)],
)
```

If you do not specify a representation, the slot trait decides the default.
Today, both `Qubit()` and `Qumode()` default to `QuantumOpticsRepr()`.

Symbolic states and operators cross the backend boundary through `express`.
That conversion is used by `initialize!`, `apply!`, `observable`, and related
register operations.

## Backend Extension Points

A new backend does not need to replace the register API. It needs to provide
the methods that let the register API lower symbolic objects and act on native
state types.

In practice, a backend integration usually defines:

- a representation type such as `CliffordRepr()`, `QuantumOpticsRepr()`, or
  `GabsRepr(...)`;
- `newstate(::QuantumStateTrait, ::YourRepr)` for empty-slot initialization;
- `default_repr(...)` for native backend state types;
- `nsubsystems` and `subsystemcompose` for factorized state management;
- native implementations of `apply!`, `observable`, `project_traceout!`, and
  `traceout!`;
- symbolic lowering through `express(..., ::YourRepr)` or `express_nolookup`;
- and, if the backend supports background evolution, `uptotime!` plus the
  background helpers it needs such as `paulinoise`, `krausops`, or
  `lindbladop`.

Those are the concrete points where the built-in backends connect today.

## What Changes And What Stays Stable

When you switch backends, the following usually stays the same:

- the register and network structure,
- the symbolic states and operators,
- the protocol control flow, and
- the metadata and messaging logic.

What changes is the numerical representation used once symbolic objects are
lowered and the set of operations that can be executed efficiently.

## Where To Go Next

- Read [Choosing a Backend and Modeling Tradeoffs](@ref modeling-tradeoffs) for
  the higher-level modeling discussion.
- Read [Symbolic Frontend](@ref symbolic-frontend) for how symbolic objects
  reach these backends.
- Read [QuantumInterface.jl reference](API_Interface.md) for the representation
  types exposed to the docs.
