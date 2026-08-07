# Register Operations

- **Context need:** Reference
- **Open when:** Checking current register operation ordering, composition, tracing, or backend-dispatch boundaries.
- **Do not open when:** Learning the ownership model, adding a backend, or working only on tags and messages.
- **Review when:** `initialize!`, `apply!`, `observable`, `project_traceout!`, `traceout!`, `uptotime!`, `overwritetime!`, or symbolic lowering changes.

## Operation contract

Register operations validate slot ownership and dispatch backend-specific work. Time
advancement is operation-specific, not automatic:

| Operation | Time behavior | Storage or result |
|---|---|---|
| `initialize!` | Changes access time only when `time` is supplied | A plain state shares one `StateRef`; symbolic `STensor` factors install separately |
| `apply!` | Advances selected state to their maximum access time, or a supplied non-earlier time | Composes distinct references and persists the joint state |
| `observable` | Advances only when `time` is supplied | Temporarily composes independent references without changing factorization |
| `project_traceout!` | Advances only when `time` is supplied | Returns the backend outcome and destructively removes the measured subsystem and back-reference |
| `traceout!` | Does not advance time | Destructively removes requested subsystems |
| `overwritetime!` | Writes the supplied value without evolution or monotonicity validation | Access-time metadata only; valid use remains nondecreasing |

`project_traceout!` returns a one-based outcome index for the discrete projective
backends. QuantumOptics accepts `Ket`/`Operator` states and symbolic or native basis
vectors; `MCKet` preserves its wrapper when a ket remains. Clifford accepts a
`MixedDestabilizer` with supported symbolic Pauli measurement bases. Gabs instead
accepts `GaussianState` plus `HomodyneMeasurement` and returns the continuous homodyne
result. Other combinations stop at dispatch. An unassigned slot throws
`ArgumentError("Cannot project and trace out an unassigned register slot.")`
before time advancement. Clifford's supported symbolic Pauli bases are specifically
`X`, `Y`, and `Z`; explicit basis vectors remain a QuantumOptics/QuantumMC feature.

`traceout!` groups slots that share a state reference. An exception after one group
succeeds may leave that group removed; no rollback or post-exception consistency is
promised. See the [backend matrix](../simulation/backend-support.md) for
representation-specific reduction semantics.

`uptotime!` evolves each distinct state through its background model toward the
requested time. Current ordering can evolve a stored backend state before detecting
that the requested target precedes a selected slot's local access time. An exception
does not establish that nothing changed. Local-time and background behavior belongs
with the time/noise reference.

## Anchors

- **Source:** [`src/baseops/initialize.jl`](../../../src/baseops/initialize.jl), [`src/baseops/apply.jl`](../../../src/baseops/apply.jl), [`src/baseops/observable.jl`](../../../src/baseops/observable.jl), [`src/baseops/traceout.jl`](../../../src/baseops/traceout.jl), and [`src/baseops/uptotime.jl`](../../../src/baseops/uptotime.jl) — operation sequencing and grouping.
- **Docs:** [`docs/src/register_interface.md`](../../../docs/src/register_interface.md) and [`docs/src/symbolic_frontend.md`](../../../docs/src/symbolic_frontend.md) — public operations and symbolic boundary.
- **Test:** [`test/general/apply_tests.jl`](../../../test/general/apply_tests.jl), [`test/general/observable_tests.jl`](../../../test/general/observable_tests.jl), [`test/general/project_traceout_tests.jl`](../../../test/general/project_traceout_tests.jl), [`test/general/project_traceout_gabs_homodyne_tests.jl`](../../../test/general/project_traceout_gabs_homodyne_tests.jl), and [`test/general/traceout_tests.jl`](../../../test/general/traceout_tests.jl) — executable behavior.

## Failure boundary

After any exception, stop the affected simulation. Public operations intentionally do
not expend extra work restoring prior register, ownership, or time state.
