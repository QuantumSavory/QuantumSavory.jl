# Backend Support

- **Context need:** Reference
- **Open when:** Comparing representation support for lowering, operations, noise, traceout, and observables.
- **Do not open when:** Adding a backend, learning the public register API, or changing only protocol logic.
- **Review when:** Representation traits, backend modules, default representations, or backend-specific tests change.

## Implemented capability boundaries

Backend support is a dispatch matrix, not a single “supported” flag:

| Representation | Stored state and implemented surface | Current limits |
|---|---|---|
| `QuantumOpticsRepr` | `Ket` and `Operator` paths for symbolic lowering, application, observables, project/traceout, finite-Fock homodyne, backgrounds, and non-instant evolution | Cost grows exponentially; homodyne samples the truncated quadrature spectrum |
| `QuantumMCRepr` | General QuantumOptics-family simulation with a distinct internal `MCKet` pure-trajectory wrapper; sampled background branches, projective measurement, and canonical-basis sampled traceout | All-`MCKet` composition preserves the wrapper; mixing with a plain `Ket` exits to `Ket`, and composition with an `Operator` promotes through a density operator |
| `CliffordRepr` | `MixedDestabilizer` stabilizer application, Pauli observables/projective measurement, symbolic stabilizer-projector observables on indexed and mixed tableaux, traceout, and T2/depolarization trajectories | Dense observables convert only pure tableaux to exponentially sized kets; mixed dense observables error |
| `GabsRepr` | Gaussian-state composition and Gaussian unitary/channel application; homodyne `project_traceout!` returns `qθ = x*cos(θ) + p*sin(θ)` and performs partial trace | Uses a fixed internal `1e-12` projector variance factor; no general `observable`, native background `uptotime!`, or `apply_noninstant!` for `ConstantHamiltonianEvolution` |

`PauliNoise` is not currently usable through normal evolution dispatch. QuantumOptics
defines `krausops(::PauliNoise)` and Clifford defines
`paulinoise(::PauliNoise)`, but their callers supply a duration argument. The apparent
helpers therefore do not implement those backend/noise pairs.

The trait implementation and backend guide map both `Qubit` and `Qumode` to
`QuantumOpticsRepr`; `Register` applies those defaults slot by slot. Gabs and Clifford
are explicit specialized choices, while `QuantumMCRepr` is a general peer of the
ordinary QuantumOptics representation and does not require conversion to it.
Representation-default changes are the specific exception to ordinary SemVer
protection.

Generic register operations may work for a backend when its primitive methods and
traits satisfy the contract. Conversely, exported symbols or included files alone are
weak evidence. Use the representation-dispatch and backend-specific tests as the
current executable boundary.

## Promotion gaps

This checkout has no generic representation-promotion layer. Symbolic initialization
calls `consistent_representation`, which currently rejects mixed requested
representations; later register operations lower from the stored native state and
normally expose missing dispatch. There is no general specialized-to-QuantumOptics
conversion, mixed-state common-representation selection, promotion-time selection or
propagation of representation approximation settings, or explicit twirling object for
a requested general-to-specialized conversion. `QuantumOpticsRepr` already carries a
finite-basis `cutoff`; future representation-specific controls belong on representation
constructors, and the existing setting is not promotion plumbing.

The dense-observable Clifford path is a narrow exception: a pure tableau is converted
to a ket and emits a `maxlog=1` backend warning. It is not the generic promotion and
once-per-call-site warning mechanism expected for automatic promotion. The planned
warning names only the initial and final representations; no such generic warning
exists yet.

Unsupported paths do not uniformly preserve Julia's `MethodError` signal.
`consistent_representation` and generic symbolic lowering use ordinary `error(...)` in
some mixed or missing cases, and selected Clifford/background implementations also
raise explicit generic errors. Registered `MethodError` hints currently cover optional
plotting and discovery calls, not representation capability or promotion failures.

## Anchors

- **Source:** [`src/traits_and_defaults.jl`](../../../src/traits_and_defaults.jl), [`src/baseops/initialize.jl`](../../../src/baseops/initialize.jl), [`src/backends/quantumoptics/`](../../../src/backends/quantumoptics/), [`src/backends/clifford/`](../../../src/backends/clifford/), and [`src/backends/gabs/`](../../../src/backends/gabs/) — defaults, current consistency selection, and backend implementations.
- **Docs:** [`docs/src/backendsimulator.md`](../../../docs/src/backendsimulator.md) and [`docs/src/restricted_formalisms.md`](../../../docs/src/restricted_formalisms.md) — current representation guidance and default policy.
- **Test:** [`test/general/representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl), [`test/general/quantummc_repr_tests.jl`](../../../test/general/quantummc_repr_tests.jl), [`test/general/project_traceout_gabs_homodyne_tests.jl`](../../../test/general/project_traceout_gabs_homodyne_tests.jl), and [`test/general/project_traceout_quantumoptics_homodyne_tests.jl`](../../../test/general/project_traceout_quantumoptics_homodyne_tests.jl) — exercised capabilities.

## Unresolved questions

- Which `PauliNoise` signatures are intended, and which backends must support them?
