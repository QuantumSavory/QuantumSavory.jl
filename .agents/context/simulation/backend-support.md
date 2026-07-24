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
| `QuantumOpticsRepr` | Exact `Ket` and `Operator` paths for symbolic lowering, application, observables, project/traceout, backgrounds, and non-instant evolution | Cost grows densely; individual state/background combinations still depend on lowering helpers |
| `QuantumMCRepr` | Distinct internal `MCKet` pure-trajectory wrapper; sampled background branches, projective measurement, and canonical-basis sampled traceout | All-`MCKet` composition preserves the wrapper; mixing with a plain `Ket` exits to `Ket`, and composition with an `Operator` promotes through a density operator |
| `CliffordRepr` | `MixedDestabilizer` stabilizer application, Pauli observables/projective measurement, traceout, and T2/depolarization trajectories | Dense observables convert only pure tableaux to exponentially sized kets; mixed dense observables error, and `SProjector` requires the entire stored tableau rather than an embedded subset |
| `GabsRepr` | Gaussian-state composition and Gaussian unitary/channel application; homodyne `project_traceout!` performs measurement and partial trace | No general `observable`, native background `uptotime!`, or `apply_noninstant!` for `ConstantHamiltonianEvolution` |

`PauliNoise` is not currently usable through normal evolution dispatch. QuantumOptics
defines `krausops(::PauliNoise)` and Clifford defines
`paulinoise(::PauliNoise)`, but their callers supply a duration argument. The apparent
helpers therefore do not implement those backend/noise pairs.

The current trait implementation and backend guide map both `Qubit` and `Qumode` to
`QuantumOpticsRepr`, while the 0.7.0 `CHANGELOG.md` entry says Gabs became the default
for qumodes. Treat the intended default as an unresolved source/history conflict.

Generic register operations may work for a backend when its primitive methods and
traits satisfy the contract. Conversely, exported symbols or included files alone are
weak evidence. Use the representation-dispatch and backend-specific tests as the
current executable boundary.

## Anchors

- **Source:** [`src/traits_and_defaults.jl`](../../../src/traits_and_defaults.jl), [`src/backends/quantumoptics/`](../../../src/backends/quantumoptics/), [`src/backends/clifford/`](../../../src/backends/clifford/), and [`src/backends/gabs/`](../../../src/backends/gabs/) — defaults and backend implementations.
- **Docs:** [`docs/src/backendsimulator.md`](../../../docs/src/backendsimulator.md), [`docs/src/restricted_formalisms.md`](../../../docs/src/restricted_formalisms.md), and [`CHANGELOG.md`](../../../CHANGELOG.md) — current guidance and the conflicting 0.7.0 default claim.
- **Test:** [`test/general/representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl), [`test/general/quantummc_repr_tests.jl`](../../../test/general/quantummc_repr_tests.jl), and [`test/general/project_traceout_gabs_homodyne_tests.jl`](../../../test/general/project_traceout_gabs_homodyne_tests.jl) — exercised capabilities.

## Unresolved questions

- Which `PauliNoise` signatures are intended, and which backends must support them?
- Should `Qumode` default to Gabs, QuantumOptics, or require explicit selection?
