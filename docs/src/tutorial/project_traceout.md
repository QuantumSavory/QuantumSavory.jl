# Measure and remove quantum systems with `project_traceout!`

This tutorial shows how to use [`project_traceout!`](@ref) for discrete and
continuous measurements. You will measure qubits and qumodes. You will also
check the state that remains after each measurement.

`project_traceout!` does two operations. First, it projects the measured system
onto a measurement outcome. This projection changes any system that is
entangled with it. Then, it removes the measured system from the register slot.

For a discrete measurement, the function returns a one-based index into the
measurement basis. The index is not an eigenvalue. For a homodyne measurement,
the function returns continuous quadrature data.

The examples set the random seed so that the displayed results are repeatable.
A measurement in a simulation is still random unless the input state fixes its
result.

The first three examples use the default `QuantumOpticsRepr()`. The homodyne
example selects `GabsRepr` explicitly.

## Measure a qubit with a Pauli operator

Start with a Bell state. Its two qubits have the same result in the ``Z`` basis.
Pass `Z` to select its eigenbasis, `(Z1, Z2)`.

```@example project_traceout
using QuantumSavory
using Random

Random.seed!(42)

qubits = Register(2)
bell = (Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2)
initialize!(qubits[1:2], bell)

outcome = project_traceout!(qubits[1], Z)
partner_state = (Z1, Z2)[outcome]

(
    outcome = outcome,
    measured_slot_is_assigned = isassigned(qubits, 1),
    partner_fidelity = observable(qubits[2], SProjector(partner_state)),
)
```

The result is `2`, so the measured qubit was projected onto `Z2`. The
`partner_fidelity` is `1.0`, so the other qubit also collapsed to `Z2`. The
measured slot is now empty.

You can use `X` or `Y` in the same way. Each operator selects its own pair of
eigenstates.

## Give the qubit basis explicitly

An explicit tuple or vector sets both the basis and the order of the outcomes.
Measure a new Bell pair in the ``X`` basis.

```@example project_traceout
Random.seed!(42)

qubits = Register(2)
initialize!(qubits[1:2], bell)

x_basis = (X1, X2)
outcome = project_traceout!(qubits[1], x_basis)
partner_state = x_basis[outcome]

(
    outcome = outcome,
    partner_fidelity = observable(qubits[2], SProjector(partner_state)),
)
```

The Bell pair is also correlated in the ``X`` basis. Outcome `2` means `X2`
because `X2` is the second item in `x_basis`. The projector observable confirms
that the other qubit is in the same state.

Use this form when you need direct control of the basis order. The basis states
must form a complete orthonormal basis for the measured system.

## Measure photon number in a qumode

A qumode has a Fock basis of photon-number states. This example uses the
default `QuantumOpticsRepr()`, which has Fock states `F0`, `F1`, and
`FockState(2)`. The prepared pair has either zero photons in both modes or one
photon in both modes.

```@example project_traceout
Random.seed!(42)

modes = Register(fill(Qumode(), 2))
mode_pair = (F0 ⊗ F0 + F1 ⊗ F1) / sqrt(2)
initialize!(modes[1:2], mode_pair)

fock_basis = (F0, F1, FockState(2))
outcome = project_traceout!(modes[1], fock_basis)
partner_state = fock_basis[outcome]

(
    outcome = outcome,
    partner_photon_number = real(observable(modes[2], N)),
    partner_fidelity = observable(modes[2], SProjector(partner_state)),
)
```

Outcome `2` selects `F1`, which is the one-photon state. The photon-number
observable is therefore `1.0`. The projector observable also gives a fidelity
of `1.0` for `F1`.

Pass the Fock states explicitly for this measurement. `N` is available as an
observable, but it is not currently available as the basis argument of
`project_traceout!`.

## Measure a continuous quadrature

A homodyne measurement returns a continuous value. Use `0.0` as the angle for
the ``x`` quadrature. Use `pi / 2` for the ``p`` quadrature. This operation is
available for qumodes that use `GabsRepr`.

The measured coherent state and the remaining vacuum state are independent in
this small example. The homodyne result is random, but the remaining mode must
still have zero photons.

```@example project_traceout
using Gabs

Random.seed!(42)

gabs_repr = GabsRepr(QuadBlockBasis)
modes = Register(fill(Qumode(), 2), fill(gabs_repr, 2))
initialize!(modes[1:2], CoherentState(0.3 + 0.2im) ⊗ F0)

result = project_traceout!(
    modes[1],
    HomodyneMeasurement([0.0]; squeeze = 1e-12),
)

# GabsRepr does not yet support `observable`. Convert a copy for this check.
remaining_state = copy(QuantumSavory.stateof(modes[2]).state[])
check_state = express(remaining_state, QuantumOpticsRepr())

(
    x_result = round(result[1]; digits = 3),
    measured_slot_is_assigned = isassigned(modes, 1),
    remaining_photons = real(observable(check_state, [1], N)),
)
```

For one mode, the result contains ``x`` and ``p`` phase-space values. Index `1`
is the measured ``x`` value in this example. For a ``p`` measurement, use angle
`pi / 2` and read index `2`. The other value is the conjugate quadrature in the
finite-squeezing approximation.

The final observable is zero, as expected for the vacuum state. The conversion
is only a check on a copy of the state. It does not change the register.

## What to carry forward

- Pass `X`, `Y`, or `Z` for a qubit Pauli measurement.
- With `QuantumOpticsRepr` or `QuantumMCRepr`, pass an ordered tuple or vector
  for an explicit discrete basis.
- Use an explicit Fock basis for a discrete qumode measurement with these
  representations.
- Pass `HomodyneMeasurement` to `GabsRepr` for a continuous qumode measurement.
- Use the returned discrete index to select the matching basis state.
- Remember that the measured slot is empty after every successful call.

For exact signatures, see the [Register Interface](../register_interface.md).
For backend limits, see [Backend Simulators](@ref backend).
