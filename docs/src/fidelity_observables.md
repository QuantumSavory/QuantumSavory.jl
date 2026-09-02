# [Fidelity and Observables](@id fidelity-observables)

The usual way to ask "how close is this register state to a target?" in
QuantumSavory is not a separate `fidelity()` function. It is
[`observable`](@ref) of a projector onto that target.

This is deliberate. "Fidelity" is used for several different quantities
(state fidelity to a ket, entanglement fidelity of a channel, gate fidelity,
Uhlmann fidelity of two mixed states). A single `fidelity(ρ, σ)` name would
not say which one you meant. `observable(slots, projector(target))` does:
it is the expectation of `|target⟩⟨target|` on the slots you named.

Helstrom bounds, quantum Chernoff bounds, and other two-state distinguishability
measures are not expectations of an operator on one register state. They do
not go through `observable`. If they belong anywhere as named helpers, that
is closer to QuantumSymbolics than to the register interface. They are not
added here.

## The one-line pattern

Prepare a target as a symbolic state (or a stabilizer state), wrap it in a
projector, and evaluate it on the slots that should hold that state:

```julia
using QuantumSavory

bell = StabilizerState("XX ZZ")
# equivalently, for a ket backend:
# bell = (Z1⊗Z1 + Z2⊗Z2)/√2

reg = Register(2)
initialize!(reg[1:2], bell)

observable(reg[1:2], projector(bell))   # ≈ 1
observable(reg[1:2], SProjector(bell))  # same idea; see below
```

That value is the state fidelity to `bell` when `bell` is pure, because
`F(ψ, ρ) = ⟨ψ|ρ|ψ⟩ = tr(|ψ⟩⟨ψ| ρ)`.

The same call works across the backends that can represent the projector.
`observable` already rejects mismatched register/index lengths and repeated
physical slots before any backend work. Empty slots return the `something`
keyword (default `nothing`) instead of computing a fidelity.

## `projector` versus `SProjector`

There are two projector wrappers in the symbolic stack:

- `projector(state)` / `SProjector(state)` both mean `|state⟩⟨state|` as an
  observable;
- tests and how-tos use both, depending on whether the target came in as a
  `StabilizerState`, a symbolic ket, or an explicit backend state.

Use a symbolic or stabilizer target when you can. Passing a dense ket
projector onto a Clifford register forces an exponential conversion of the
stabilizer state; QuantumSavory warns on that path. A
`projector(StabilizerState("XX ZZ"))` stays in the Clifford formalism.

Pauli correlators are often cheaper than a full projector and already answer
"is this still a Bell pair?":

```julia
observable(reg[1:2], σˣ ⊗ σˣ)  # +1 on Φ+
observable(reg[1:2], σᶻ ⊗ σᶻ)  # +1 on Φ+
```

A Bell projector is the finer statement. `XX` and `ZZ` both being +1 is
usually what people mean by "the pair is still good" in a repeater plot.

## Two registers, not just two slots

[`observable`](@ref) accepts a tuple of [`RegRef`](@ref)s, so the two halves
of a pair can live in different nodes:

```julia
net = RegisterNet([Register(1), Register(1)])
initialize!((net[1][1], net[2][1]), StabilizerState("XX ZZ"))
observable((net[1][1], net[2][1]), projector(StabilizerState("XX ZZ")))
```

The slots still have to be distinct physical slots. Observing the same
`RegRef` twice is an error, not a fidelity of 1.

## Mixed states and "which fidelity"

If the stored state is mixed, `observable(slots, projector(ψ))` is still
`⟨ψ|ρ|ψ⟩`. That is the usual overlap with a pure target. It is not the
Uhlmann fidelity `F(ρ, σ) = (tr √(√ρ σ √ρ))²` between two mixed states, and
it is not a process fidelity.

If you need Uhlmann fidelity between two mixed states, that is a two-argument
state function, not a register observable. Do not pretend `observable` is
that function.

## Size matching

`observable` already checks:

- the number of registers equals the number of slot indices;
- each physical register slot appears at most once;
- indices are in bounds.

It does not separately check "the projector Hilbert-space dimension equals
the composed backend state dimension" beyond what the backend `observable`
method does. If you pass a one-qubit projector onto two slots, that is a
backend error, not a silent `0`.

## What about Helstrom and Chernoff?

The Helstrom measurement distinguishes two states `ρ` and `σ` with minimum
error `(1 - ½‖ρ - σ‖₁)/2`. The quantum Chernoff bound is an asymptotic
pairwise distinguishability exponent. Both take *two* states, not a register
and an observable.

They are useful figures of merit. They are not `observable` calls. A
`helstrom(stateA, stateB)` helper would live next to other symbolic
state-vs-state functions, which is why the original discussion of this
feature pointed at QuantumSymbolics. This page does not invent a QuantumSavory
wrapper for them.

## Where to go next

- [Register Interface API](register_interface.md) for the `observable`
  call tree and `something` / `time` keywords.
- [Fidelity through observable](@ref tutorial-fidelity-observable) for a
  runnable Bell-pair example.
- [Restricted Formalisms and Efficient Simulation](@ref
  restricted-formalisms) for when a Clifford projector is the cheap option.
