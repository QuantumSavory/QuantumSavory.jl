# Acceptance Verification

These demonstrations validate stakeholder outcomes in representative operational
scenarios. Partial repository fixtures are durable evidence that the actions exist, not
evidence that the complete promotion criteria currently pass.

## ACC-001 — Demonstrate integrated noisy, timed network modeling

- **Covers:** STK-001
- **Method:** demonstration
- **Procedure:** Execute one two-location scenario containing an entangled resource,
  delayed classical and quantum transfers, a background process, and time-dependent
  control while recording arrivals, operations, and the final resource.
- **Environment / configuration:** Examples project at the revision under review with
  fixed nonzero delays and a supported background.
- **Pass criterion:** Classical and quantum arrivals occur no earlier than their
  separately configured delays, requested operations execute in simulated-time order,
  and the final resource report equals the reference result including the configured
  background evolution.
- **Status:** implemented
- **Evidence:** [`firstgenrepeater_1_tests.jl`](../../../test/examples/firstgenrepeater_1_tests.jl), [`firstgenrepeater_3_tests.jl`](../../../test/examples/firstgenrepeater_3_tests.jl), [`congestionchain_tests.jl`](../../../test/examples/congestionchain_tests.jl)
- **Nonconformance:** The wrappers do not jointly assert both transfer delays,
  operation order, and the background-evolved final resource in one scenario.

## ACC-002 — Demonstrate reuse across compatible representations

- **Covers:** STK-002
- **Method:** demonstration
- **Procedure:** Execute one representation-independent Bell-pair model and protocol
  unchanged first with the general default and then with a specialized representation
  that requires automatic promotion for one operation.
- **Environment / configuration:** Root or examples project with fixed inputs,
  `QuantumOpticsRepr`, and one compatible `CliffordRepr` or `GabsRepr` fixture.
- **Pass criterion:** Both runs satisfy the same expected deterministic parity checks,
  the symbolic model, topology, and protocol configuration remain identical, and the
  specialized run warns once at the promotion call site with the initial and final
  representation names.
- **Status:** implemented
- **Evidence:** [`observable_tests.jl`](../../../test/general/observable_tests.jl), [`firstgenrepeater_lowlevel_6_1_tests.jl`](../../../test/examples/firstgenrepeater_lowlevel_6_1_tests.jl), [`assisted_cvteleportation_tests.jl`](../../../test/examples/assisted_cvteleportation_tests.jl)
- **Nonconformance:** Existing parity and example fixtures are separate scenarios.
  They neither prove unchanged topology/protocol configuration nor exercise the
  intended general automatic-promotion path.

## ACC-003 — Demonstrate asynchronous protocol composition

- **Covers:** STK-003
- **Method:** demonstration
- **Procedure:** Run concurrent producer and consumer processes at different locations
  using a predefined resource model, an immediate quantum routine, delayed messages,
  metadata waits, and an exclusive slot reservation.
- **Environment / configuration:** Examples project on a deterministic small network
  with instrumented reservation ownership.
- **Pass criterion:** The consumer proceeds only after every prerequisite is present,
  no observation shows overlapping ownership of the reserved slot, and the composed
  workflow produces the expected consumed-resource result.
- **Status:** implemented
- **Evidence:** [`qtcp_tutorial_1_tests.jl`](../../../test/examples/qtcp_tutorial_1_tests.jl), [`qtcp_tutorial_3_tests.jl`](../../../test/examples/qtcp_tutorial_3_tests.jl), [`purificationmbqc_tests.jl`](../../../test/examples/purificationmbqc_tests.jl)
- **Nonconformance:** No single fixture combines all required building blocks and
  asserts prerequisite ordering, reservation non-overlap, and the consumed result.

## ACC-004 — Demonstrate the complete repository-owned product

- **Covers:** STK-004
- **Method:** demonstration
- **Procedure:** Build the generated documentation and execute the CI-routed general,
  Zoo, example, plotting, and built-in optional-integration workflows, including one
  user-oriented scenario and one low-level modeling example.
- **Environment / configuration:** Revision under review in every declared
  CI-supported Julia/platform/dependency configuration; configured external services
  are available for the documentation integration.
- **Pass criterion:** Core operations, every public Zoo family, every checked-in
  example, documentation generation, and each repository-owned optional feature
  complete through their supported user boundary in the configurations that declare
  them supported. The user-oriented and low-level examples remain clearly identified.
- **Status:** implemented
- **Evidence:** [`pipeline.yml`](../../../.buildkite/pipeline.yml), [`ci.yml`](../../../.github/workflows/ci.yml), [`runtests.jl`](../../../test/runtests.jl), [`make.jl`](../../../docs/make.jl), [`API_StatesZoo.md`](../../../docs/src/API_StatesZoo.md), [`API_CircuitZoo.md`](../../../docs/src/API_CircuitZoo.md), [`API_ProtocolZoo.md`](../../../docs/src/API_ProtocolZoo.md)
- **Nonconformance:** CI defines separate shards, but no durable whole-product run
  proves every public Zoo entry and checked-in example across all declared
  configurations. The documentation path also depends on credentials and an external
  service.

## ACC-005 — Demonstrate inspection and diagnosis

- **Covers:** STK-005
- **Method:** demonstration
- **Procedure:** Inspect one representative scenario before and after execution, capture
  records from each documented stable log group, and invoke every supported renderer.
- **Environment / configuration:** Declared examples and plotting environments with a
  fixed model configuration.
- **Pass criterion:** Inspection exposes configured representations, backgrounds,
  ownership, and final state without changing simulation state; records are routed to
  their documented log groups; and every supported text, HTML, image, plotting, or map
  renderer completes. No exact log payload or rendered content is compared.
- **Status:** implemented
- **Evidence:** [`state_explorer_tests.jl`](../../../test/examples/state_explorer_tests.jl), [`qtcp_tutorial_2_tests.jl`](../../../test/examples/qtcp_tutorial_2_tests.jl), [`firstgenrepeater_lowlevel_1_tests.jl`](../../../test/examples/firstgenrepeater_lowlevel_1_tests.jl)
- **Nonconformance:** Current fixtures inspect and render selected objects only; they do
  not cover every public inspection entry point, stable log group, or supported
  renderer in one scenario.
