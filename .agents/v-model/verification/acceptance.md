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
- **Environment / configuration:** Examples project at the profile-pinned product
  revision with fixed nonzero delays and a supported background.
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
  unchanged with two representations that support every requested capability.
- **Environment / configuration:** Root or examples project with fixed inputs and two
  confirmed compatible representations.
- **Pass criterion:** Both runs satisfy the same expected deterministic parity checks,
  and the symbolic model, topology, and protocol configuration remain identical between
  runs.
- **Status:** implemented
- **Evidence:** [`observable_tests.jl`](../../../test/general/observable_tests.jl), [`firstgenrepeater_lowlevel_6_1_tests.jl`](../../../test/examples/firstgenrepeater_lowlevel_6_1_tests.jl), [`assisted_cvteleportation_tests.jl`](../../../test/examples/assisted_cvteleportation_tests.jl)
- **Nonconformance:** Existing parity and example fixtures are separate scenarios; none
  proves unchanged topology and protocol configuration across two representations.

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

## ACC-004 — Demonstrate independently packaged extensions

- **Covers:** STK-004
- **Method:** demonstration
- **Procedure:** At product revision
  `d7523d33e10bbb199e26a7dea074a54f34646d24`, build a separate external package
  fixture for every extension class in the confirmed inventory, exercise each through
  its normal user-facing boundary, probe an unsupported type, compare core source, and
  repeat a representation-independent built-in baseline before and after loading.
- **Environment / configuration:** Clean Julia environments developing that exact
  QuantumSavory checkout plus only the fixture package and its declared dependencies.
- **Pass criterion:** Every supported fixture is selected through the same boundary as
  built-in behavior and returns its asserted result, the unsupported type remains
  unselected, no QuantumSavory core source differs from the pinned checkout, and the
  pre/post built-in baseline result is unchanged.
- **Status:** planned
- **Evidence:** None
- **Nonconformance:** The inventory is unconfirmed; no independently packaged fixture
  or pre/post built-in baseline comparison exists.

## ACC-005 — Demonstrate inspection, diagnostics, and reproducibility

- **Covers:** STK-005
- **Method:** demonstration
- **Procedure:** Inspect one representative scenario before and after execution, capture
  selected structured records, then make two fresh runs from the same initial model and
  scheduling configuration after resetting all Julia RNG state used by the scenario.
- **Environment / configuration:** Declared software environment in examples and
  plotting projects with fixed model configuration and seed.
- **Pass criterion:** Inspection exposes configured representations, backgrounds,
  ownership, and final state; selected diagnostics expose their documented domain,
  event, simulation time, and process identity; and, under the same fixed environment,
  initial model, scheduling configuration, and reset Julia RNG state, the two fresh
  runs agree on selected scientific outcomes, event times, and RNG-derived protocol
  identifiers. Internal monotonic storage IDs are compared only if their counters reset.
- **Status:** implemented
- **Evidence:** [`state_explorer_tests.jl`](../../../test/examples/state_explorer_tests.jl), [`qtcp_tutorial_2_tests.jl`](../../../test/examples/qtcp_tutorial_2_tests.jl), [`firstgenrepeater_lowlevel_1_tests.jl`](../../../test/examples/firstgenrepeater_lowlevel_1_tests.jl)
- **Nonconformance:** Current fixtures neither inspect the complete declared state nor
  repeat one fully seeded run to compare outcomes, times, and protocol identifiers.
