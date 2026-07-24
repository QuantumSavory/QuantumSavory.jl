# Backend Support

- **Context need:** Reference
- **Open when:** Comparing representation support for lowering, operations, noise, traceout, and observables.
- **Do not open when:** Adding a backend, learning the public register API, or changing only protocol logic.
- **Related specification IDs:** SYS-001, SYS-003, SYS-007, SUB-010, CMP-009
- **Review when:** Representation traits, backend modules, default representations, or backend-specific tests change.

## Implemented capability boundaries

Backend support is a dispatch matrix, not a single “supported” flag. Confirm the exact
state, operation, and background combination in source and tests before promising it.

`QuantumOpticsRepr` is the broad numeric path for qubits and qumodes. It covers ket and
operator representations and includes Monte Carlo trajectories through `MCKet`.
`MCKet` traceout samples the discarded subsystem in its canonical basis and retains the
conditional trajectory; it is deliberately not density-matrix partial trace semantics.
The `PauliNoise` helper methods in the QuantumOptics and Clifford evolution files
currently have signatures inconsistent with their callers, so their apparent presence
does not establish working support.

`CliffordRepr` is restricted to stabilizer-compatible states and operations. Its
background evolution currently implements T2 dephasing and depolarization paths, not
the full background catalog. Unsupported symbolic inputs should fail at the backend
boundary rather than be silently approximated.

`GabsRepr` provides a narrower Gaussian path. The implemented surface includes Gaussian
application, homodyne-related projection/traceout, representation defaults, and display
support; do not infer parity with QuantumOptics from the shared register interface.
The current trait implementation and backend guide map both `Qubit` and `Qumode` to
`QuantumOpticsRepr`, but the 0.7.0 `CHANGELOG.md` entry says Gabs became the default for
qumodes. Treat the intended default as an unresolved source/history conflict.

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
