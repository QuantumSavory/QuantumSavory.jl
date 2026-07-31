# Backend Support

- **Context need:** Reference
- **Open when:** Comparing representation support for lowering, operations, noise, traceout, and observables.
- **Do not open when:** Adding a backend, learning the public register API, or changing only protocol logic.
- **Related specification IDs:** SYS-001, SYS-003, SYS-007, SUB-010, CMP-009
- **Review when:** Representation traits, backend modules, default representations, or backend-specific tests change.

## Implemented capability boundaries

Backend support is a dispatch matrix, not a single “supported” flag:

| Representation | Stored state and implemented surface | Current limits |
|---|---|---|
| `QuantumOpticsRepr` | `Ket` and `Operator` paths for symbolic lowering, application, observables, project/traceout, backgrounds, and non-instant evolution | Cost grows densely; individual state/background combinations still depend on lowering helpers |
| `QuantumMCRepr` | General QuantumOptics-family simulation with a distinct internal `MCKet` pure-trajectory wrapper; sampled background branches, projective measurement, and canonical-basis sampled traceout | All-`MCKet` composition preserves the wrapper; mixing with a plain `Ket` exits to `Ket`, and composition with an `Operator` promotes through a density operator |
| `CliffordRepr` | `MixedDestabilizer` stabilizer application, Pauli observables/projective measurement, traceout, and T2/depolarization trajectories | Dense observables convert only pure tableaux to exponentially sized kets; mixed dense observables error, and `SProjector` requires the entire stored tableau rather than an embedded subset |
| `GabsRepr` | Gaussian-state composition and Gaussian unitary/channel application; homodyne `project_traceout!` performs measurement and partial trace | No general `observable`, native background `uptotime!`, or `apply_noninstant!` for `ConstantHamiltonianEvolution` |

`PauliNoise` is not currently usable through normal evolution dispatch. QuantumOptics
defines `krausops(::PauliNoise)` and Clifford defines
`paulinoise(::PauliNoise)`, but their callers supply a duration argument. The apparent
helpers therefore do not implement those backend/noise pairs.

The trait implementation and backend guide map both `Qubit` and `Qumode` to
`QuantumOpticsRepr`; `Register` applies those defaults slot by slot. The 0.7.0
`CHANGELOG.md` statement that Gabs became the qumode default is incorrect. Gabs and
Clifford are explicit specialized choices, while `QuantumMCRepr` is a general peer of
the ordinary QuantumOptics representation and does not require conversion to it.
SYS-007 treats representation-default changes as the specific exception to ordinary
SemVer protection; this does not make the stale changelog statement current.

Generic register operations may work for a backend when its primitive methods and
traits satisfy the contract. Conversely, exported symbols or included files alone are
weak evidence. Use the representation-dispatch and backend-specific tests as the
current executable boundary.

## Promotion gaps

This checkout has no generic representation-promotion layer. Symbolic initialization
calls `consistent_representation`, which currently rejects mixed requested
representations; later register operations lower from the stored native state and
normally expose missing dispatch. There is no general specialized-to-QuantumOptics
conversion, mixed-state common-representation selection, approximation configuration
on representation constructors, or explicit twirling object for a requested
general-to-specialized conversion.

The dense-observable Clifford path is a narrow exception: a pure tableau is converted
to a ket and emits a `maxlog=1` backend warning. It is not the generic promotion and
once-per-call-site warning mechanism described by SYS-007, SUB-010, and CMP-009. The
planned warning names only the initial and final representations; no such generic
warning exists yet.

## Anchors

- **Source:** [`src/traits_and_defaults.jl`](../../../src/traits_and_defaults.jl), [`src/baseops/initialize.jl`](../../../src/baseops/initialize.jl), [`src/backends/quantumoptics/`](../../../src/backends/quantumoptics/), [`src/backends/clifford/`](../../../src/backends/clifford/), and [`src/backends/gabs/`](../../../src/backends/gabs/) — defaults, current consistency selection, and backend implementations.
- **Docs:** [`docs/src/backendsimulator.md`](../../../docs/src/backendsimulator.md), [`docs/src/restricted_formalisms.md`](../../../docs/src/restricted_formalisms.md), and [`CHANGELOG.md`](../../../CHANGELOG.md) — current guidance and the stale 0.7.0 default claim.
- **Test:** [`test/general/representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl), [`test/general/quantummc_repr_tests.jl`](../../../test/general/quantummc_repr_tests.jl), and [`test/general/project_traceout_gabs_homodyne_tests.jl`](../../../test/general/project_traceout_gabs_homodyne_tests.jl) — exercised capabilities.

## Unresolved questions

- Which `PauliNoise` signatures are intended, and which backends must support them?
