# System Quality and Inspection Verification

These actions cover package-level diagnostics, compatibility, reproducibility, and
inspection behavior.

## SYSV-008 — Verify diagnostics, optional UI, and compatibility

- **Covers:** SYS-010, SYS-011
- **Method:** test
- **Procedure:** Test clean core-only load, each complete weak-dependency set,
  representative diagnostics, and every inspection entry point.
- **Environment / configuration:** [`Project.toml`](../../../Project.toml) compatibility,
  isolated projects, and configured CI platforms.
- **Pass criterion:** Core loading and operations succeed without optional UI
  dependencies; each complete weak-dependency set activates only its corresponding
  extension; every activated inspection entry point returns its documented result; and
  representative diagnostics contain documented domain, event, simulation time, and
  process identity without retaining mutable simulation objects.
- **Status:** implemented
- **Evidence:** [`Project.toml`](../../../Project.toml), [`ci.yml`](../../../.github/workflows/ci.yml), [`downgrade.yml`](../../../.github/workflows/downgrade.yml), [`pipeline.yml`](../../../.buildkite/pipeline.yml), [`logging_tests.jl`](../../../test/general/logging_tests.jl), [`interactiveutils_tests.jl`](../../../test/general/interactiveutils_tests.jl), [`show_html_tests.jl`](../../../test/general/show_html_tests.jl), [`protocol_show_html_contracts_tests.jl`](../../../test/general/protocol_show_html_contracts_tests.jl), [`cairo_tests.jl`](../../../test/plotting/cairo_tests.jl), [`gl_tests.jl`](../../../test/plotting/gl_tests.jl), [`show_png_tests.jl`](../../../test/plotting/show_png_tests.jl), [`doctests_tests.jl`](../../../test/plotting/doctests_tests.jl)
- **Nonconformance:** No clean activation matrix exists; logs/rendering are sampled,
  docs need credentials, and only `general` is cross-platform.

## SYSV-009 — Verify designated seeded workflow repetition

- **Covers:** SYS-012
- **Method:** test
- **Procedure:** Execute two fresh runs with one fixed environment, model, schedule, and
  reset Julia RNG state; capture outcomes, times, and protocol IDs.
- **Environment / configuration:** Exclude external services and unspecified threaded
  schedules; compare monotonic IDs only when counters reset.
- **Pass criterion:** For a scenario whose random choices use Julia RNG state, both
  fresh runs agree on selected scientific outcomes, simulated event times, and
  RNG-derived protocol identifiers after resetting that state to the same seed.
  Internal monotonic storage identities are excluded unless their counters are reset.
- **Status:** planned
- **Evidence:** [`traceout_tests.jl`](../../../test/general/traceout_tests.jl), [`quantummc_repr_tests.jl`](../../../test/general/quantummc_repr_tests.jl), [`project_traceout_gabs_homodyne_tests.jl`](../../../test/general/project_traceout_gabs_homodyne_tests.jl)
- **Nonconformance:** These seed isolated operations, not two complete fresh workflows.
  Global/task RNG use spans scheduling, pair-ID, backend, and MBQC paths.

## SYSV-010 — Verify public inspection and network metadata

- **Covers:** SYS-013
- **Method:** test
- **Procedure:** Inspect shared register state, indexed network topology, and vertex,
  undirected-edge, directed-edge, and bulk metadata through public boundaries.
- **Environment / configuration:** Root tests with multiple registers, one shared state,
  and unequal opposing directed values.
- **Pass criterion:** Inspection reports assignment, shared ownership, and native state
  without mutation; graph/index queries reproduce topology, registers, and slots;
  metadata round-trips; undirected lookup is endpoint-order invariant, opposing directed
  values remain distinct, and bulk access or assignment covers the existing vertex or
  edge collection.
- **Status:** implemented
- **Evidence:** [`observable_tests.jl`](../../../test/general/observable_tests.jl), [`show_html_tests.jl`](../../../test/general/show_html_tests.jl), [`show_gabs_tests.jl`](../../../test/general/show_gabs_tests.jl), [`registernet_interface_tests.jl`](../../../test/general/registernet_interface_tests.jl), [`registernet_metadata_access_tests.jl`](../../../test/general/registernet_metadata_access_tests.jl)
- **Nonconformance:** Network tests cover most addressing modes, but no fixture proves
  state inspection and rendering are non-mutating or combines every system clause.
