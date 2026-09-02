# [Fidelity through observable](@id tutorial-fidelity-observable)

This tutorial is one narrow skill: compute overlap with a Bell pair (and a
Pauli correlator) using [`observable`](@ref), without a dedicated
`fidelity()` function.

The conceptual rules are in [Fidelity and Observables](@ref
fidelity-observables).

## A Bell pair on one register

```julia
using QuantumSavory

bell = StabilizerState("XX ZZ")
reg = Register(2)
initialize!(reg[1:2], bell)

F = observable(reg[1:2], projector(bell))
F ≈ 1
```

`SProjector(bell)` is the same observable written the way several tests spell
it:

```julia
observable(reg[1:2], SProjector(bell)) ≈ 1
```

## After a local error

```julia
apply!(reg[1], σʸ)
observable(reg[1:2], projector(bell)) ≈ 0   # Φ+ is gone
observable(reg[1:2], σˣ ⊗ σˣ) ≈ -1         # XX flipped sign
```

The projector is the overlap with the target ket. The Pauli correlator is the
cheaper "is the pair still aligned on this axis?" check used in repeater
plots.

## Across two nodes

```julia
net = RegisterNet([Register(1), Register(1)])
initialize!((net[1][1], net[2][1]), bell)
observable((net[1][1], net[2][1]), projector(bell)) ≈ 1
```

`observable` requires the two slots to be distinct. Passing the same slot
twice throws, rather than returning a fake fidelity.

## Empty slots

```julia
empty = Register(2)
observable(empty[1:2], projector(bell))          # nothing
observable(empty[1:2], projector(bell); something=0.0)  # 0.0
```

There is no automatic "fidelity 0" for an unassigned slot unless you ask for
it with `something`.

## Carry this forward

- Target overlap: `observable(slots, projector(target))`.
- Cheap Bell checks: `observable(slots, σˣ⊗σˣ)` and `σᶻ⊗σᶻ`.
- Two-state distances (Helstrom, Chernoff, Uhlmann of two mixed states) are
  not `observable` and are not wrapped here.
