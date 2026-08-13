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

The first few examples use the default `QuantumOpticsRepr()`. The homodyne
example selects `GabsRepr` explicitly.

## Measure a qubit with a Pauli operator

Start with a Bell state. Its two qubits have the same result in the ``Z`` basis.
Pass `Z` to select its eigenbasis, `(Z1, Z2)`.

```@example project_traceout
using QuantumSavory

qubits = Register(2)
bell = (Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2)
initialize!(qubits[1:2], bell)

first_outcome = project_traceout!(qubits[1], Z)
partner_state = (Z1, Z2)[first_outcome]
partner_fidelity = observable(qubits[2], SProjector(partner_state))
second_outcome = project_traceout!(qubits[2], Z)

(
    measurements_match = first_outcome == second_outcome,
    partner_matches_first = isapprox(partner_fidelity, 1; atol = 1e-12),
    both_slots_are_empty = !isassigned(qubits, 1) && !isassigned(qubits, 2),
)
```

Each outcome is either `1` or `2`. The two values are always equal because the
Bell state has equal ``Z``-basis results. The projector observable checks that
the second qubit is in the state selected by the first outcome. Both slots are
empty after the second measurement.

You can use `X` or `Y` in the same way. Each operator selects its own pair of
eigenstates.

For `CliffordRepr`, symbolic `X`, `Y`, and `Z` are the currently supported
measurement bases. The explicit basis-vector form in the next section is
available with `QuantumOpticsRepr` and `QuantumMCRepr`.

## Give the qubit basis explicitly

An explicit tuple or vector sets both the basis and the order of the outcomes.
Measure a new Bell pair in the ``X`` basis.

```@example project_traceout
qubits = Register(2)
initialize!(qubits[1:2], bell)

x_basis = (X1, X2)
first_outcome = project_traceout!(qubits[1], x_basis)
partner_state = x_basis[first_outcome]
partner_fidelity = observable(qubits[2], SProjector(partner_state))
second_outcome = project_traceout!(qubits[2], x_basis)

(
    measurements_match = first_outcome == second_outcome,
    partner_matches_first = isapprox(partner_fidelity, 1; atol = 1e-12),
)
```

The Bell pair is also correlated in the ``X`` basis. If the first outcome is
`1`, the selected state is `X1`. If it is `2`, the selected state is `X2`.
The projector observable and the second measurement both confirm the
correlation without requiring either value.

Use this form when you need direct control of the basis order. The basis states
must form a complete orthonormal basis for the measured system.

## Measure photon number in a qumode

A qumode has a Fock basis of photon-number states. This example uses the
default `QuantumOpticsRepr()`, which has Fock states `F0`, `F1`, and
`FockState(2)`. The prepared pair has either zero photons in both modes or one
photon in both modes.

```@example project_traceout
modes = Register(fill(Qumode(), 2))
mode_pair = (F0 ⊗ F0 + F1 ⊗ F1) / sqrt(2)
initialize!(modes[1:2], mode_pair)

fock_basis = (F0, F1, FockState(2))
first_outcome = project_traceout!(modes[1], fock_basis)
partner_state = fock_basis[first_outcome]
partner_photon_number = real(observable(modes[2], N))
partner_fidelity = observable(modes[2], SProjector(partner_state))
second_outcome = project_traceout!(modes[2], fock_basis)

(
    populated_outcome = first_outcome in (1, 2),
    measurements_match = first_outcome == second_outcome,
    photon_number_matches = isapprox(
        partner_photon_number,
        first_outcome - 1;
        atol = 1e-12,
    ),
    partner_matches_first = isapprox(partner_fidelity, 1; atol = 1e-12),
)
```

The first outcome can select `F0` or `F1`. It cannot select `FockState(2)`
because that state has zero amplitude in the prepared pair. The photon-number
observable is zero after an `F0` result and one after an `F1` result. The two
mode measurements have the same basis index.

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
    result_has_x_and_p = length(result) == 2,
    measured_x_is_finite = isfinite(result[1]),
    measured_slot_is_empty = !isassigned(modes, 1),
    remaining_mode_is_vacuum = isapprox(
        real(observable(check_state, [1], N)),
        0;
        atol = 1e-12,
    ),
)
```

For one mode, the result contains ``x`` and ``p`` phase-space values. Index `1`
is the measured ``x`` value in this example. For a ``p`` measurement, use angle
`pi / 2` and read index `2`. The other value is the conjugate quadrature in the
finite-squeezing approximation.

The sampled ``x`` value can change between runs. The example checks only that
the result has the expected form and contains a finite measured value. The
final observable confirms that the independent second mode remains in the
vacuum state. The conversion is only a check on a copy of the state. It does
not change the register.

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
