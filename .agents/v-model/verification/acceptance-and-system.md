# Acceptance and System Verification

## ACC-001 — Demonstrate integrated noisy, timed network modeling

- **Covers:** STK-001
- **Method:** demonstration
- **Procedure:** Run the cited repeater and congestion wrappers.
- **Environment / configuration:** Examples project; supported Julia.
- **Pass criterion:** Each wrapper completes without an uncaught exception; embedded assertions hold.
- **Status:** implemented
- **Evidence:** [`firstgenrepeater_1_tests.jl`](../../../test/examples/firstgenrepeater_1_tests.jl), [`firstgenrepeater_3_tests.jl`](../../../test/examples/firstgenrepeater_3_tests.jl), [`congestionchain_tests.jl`](../../../test/examples/congestionchain_tests.jl)
- **Nonconformance:** No wrapper jointly asserts both arrival delays, operation order, and the final background-evolved resource.

## ACC-002 — Demonstrate reuse across compatible representations

- **Covers:** STK-002
- **Method:** demonstration
- **Procedure:** Run Bell parity, repeater comparison, and continuous-variable teleportation.
- **Environment / configuration:** Root/examples projects; selected backends.
- **Pass criterion:** Bell parity has the asserted value in full-state and Clifford representations; the repeater emits both traces; teleportation meets its tolerance.
- **Status:** implemented
- **Evidence:** [`observable_tests.jl`](../../../test/general/observable_tests.jl), [`firstgenrepeater_lowlevel_6_1_tests.jl`](../../../test/examples/firstgenrepeater_lowlevel_6_1_tests.jl), [`assisted_cvteleportation_tests.jl`](../../../test/examples/assisted_cvteleportation_tests.jl)
- **Nonconformance:** No test proves unchanged topology/protocol configuration; repeater traces are not numerically compared.

## ACC-003 — Demonstrate asynchronous protocol composition

- **Covers:** STK-003
- **Method:** demonstration
- **Procedure:** Run QTCP chain/grid and measurement-based purification wrappers.
- **Environment / configuration:** Examples project.
- **Pass criterion:** QTCP endpoint counts equal each requested pair count, and perfect-input purification produces present endpoint tags and unit-fidelity output assertions.
- **Status:** implemented
- **Evidence:** [`qtcp_tutorial_1_tests.jl`](../../../test/examples/qtcp_tutorial_1_tests.jl), [`qtcp_tutorial_3_tests.jl`](../../../test/examples/qtcp_tutorial_3_tests.jl), [`purificationmbqc_tests.jl`](../../../test/examples/purificationmbqc_tests.jl)
- **Nonconformance:** No single fixture combines delayed messages, metadata waits, an exclusive slot, Zoo building blocks, and a non-overlap assertion.

## ACC-004 — Demonstrate an independently packaged extension

- **Covers:** STK-004
- **Method:** demonstration
- **Procedure:** Build separate temporary-package fixtures for each confirmed extension
  class and exercise them through public boundaries.
- **Environment / configuration:** Clean Julia environment developing the pinned
  QuantumSavory checkout plus separate fixture packages.
- **Pass criterion:** Every fixture loads without modifying QuantumSavory, its custom
  behavior completes with an asserted result, and a designated unsupported request
  does not report success.
- **Status:** planned
- **Evidence:** None
- **Nonconformance:** No independently packaged extension fixture exists for any class.

## ACC-005 — Demonstrate inspection, diagnostics, and reproduction aids

- **Covers:** STK-005
- **Method:** demonstration
- **Procedure:** Run state-explorer, recorded QTCP, and structured-log wrappers.
- **Environment / configuration:** Examples/plotting projects.
- **Pass criterion:** The explorer starts and closes cleanly, QTCP emits the requested media file and endpoint counts, and the repeater emits a structured entanglement record with typed context.
- **Status:** implemented
- **Evidence:** [`state_explorer_tests.jl`](../../../test/examples/state_explorer_tests.jl), [`qtcp_tutorial_2_tests.jl`](../../../test/examples/qtcp_tutorial_2_tests.jl), [`firstgenrepeater_lowlevel_1_tests.jl`](../../../test/examples/firstgenrepeater_lowlevel_1_tests.jl)
- **Nonconformance:** No action inspects the complete declared configuration/state or
  repeats one seeded run to compare scientific outcomes, event times, and RNG-derived
  protocol identifiers.

## SYSV-001 — Verify symbolic lowering and factorized register ownership

- **Covers:** SYS-001, SYS-002
- **Method:** test
- **Procedure:** Run symbolic parity, dispatch, register, apply, and project/traceout tests.
- **Environment / configuration:** Root tests; declared qubit backends.
- **Pass criterion:** Symbolic operators lower to the selected representation, multi-register operations match explicitly represented operations, and initialize/apply/project/traceout preserve asserted subsystem ownership and state shape.
- **Status:** implemented
- **Evidence:** [`observable_tests.jl`](../../../test/general/observable_tests.jl), [`representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl), [`register_interface_tests.jl`](../../../test/general/register_interface_tests.jl), [`project_traceout_tests.jl`](../../../test/general/project_traceout_tests.jl)
- **Nonconformance:** No focused test asserts every heterogeneous declaration and explicit-factor owner identity; the backend matrix is partial.

## SYSV-002 — Verify demand-driven monotonic time and backgrounds

- **Covers:** SYS-003
- **Method:** test
- **Procedure:** Run the qubit, Clifford, and qumode noninstant/background suites.
- **Environment / configuration:** Root tests; QuantumOptics, QuantumClifford, and Gabs.
- **Pass criterion:** Forward evolution produces asserted states/observables, rewind requests throw, and tested background channels agree with reference evolutions.
- **Status:** implemented
- **Evidence:** [`noninstant_and_backgrounds_qubit_tests.jl`](../../../test/general/noninstant_and_backgrounds_qubit_tests.jl), [`noninstant_and_backgrounds_clifford_tests.jl`](../../../test/general/noninstant_and_backgrounds_clifford_tests.jl), [`noninstant_and_backgrounds_qumode_tests.jl`](../../../test/general/noninstant_and_backgrounds_qumode_tests.jl)
- **Nonconformance:** Access-time fields are unasserted; backend coverage differs and unsupported combinations lack a complete error contract.

## SYSV-003 — Verify event waits, locks, metadata queries, and consumption

- **Covers:** SYS-004, SYS-005
- **Method:** test
- **Procedure:** Run event helper, query/wait, message-buffer, and semaphore suites.
- **Environment / configuration:** Root tests; deterministic simulated time.
- **Pass criterion:** Processes wake at asserted times; query order, wait consumption, and one-item-per-consumer behavior match assertions; a delayed metadata snapshot cannot mutate a fresh reused slot.
- **Status:** implemented
- **Evidence:** [`concurrentsim_helpers_tests.jl`](../../../test/general/concurrentsim_helpers_tests.jl), [`tags_and_queries_tests.jl`](../../../test/general/tags_and_queries_tests.jl), [`querywait_tests.jl`](../../../test/general/querywait_tests.jl), [`protocolzoo_entanglement_id_tests.jl`](../../../test/general/protocolzoo_entanglement_id_tests.jl)
- **Nonconformance:** No test asserts unhandled process-failure propagation; contention and snapshot schedules are representative.

## SYSV-004 — Verify delayed classical and quantum transport

- **Covers:** SYS-006
- **Method:** test
- **Procedure:** Run per-link-delay, message-buffer, and quantum-channel tests.
- **Environment / configuration:** Root tests; deterministic small networks.
- **Pass criterion:** Directional link delays equal their configuration, classical arrival occurs at the asserted time, quantum transfer vacates the source and shares the destination state reference, and configured transit noise changes the asserted observables.
- **Status:** implemented
- **Evidence:** [`registernet_interface_tests.jl`](../../../test/general/registernet_interface_tests.jl), [`messagebuffer_tests.jl`](../../../test/general/messagebuffer_tests.jl), [`quantumchannel_tests.jl`](../../../test/general/quantumchannel_tests.jl)
- **Nonconformance:** There is no direct classical-forwarding test, no focused
  malformed-network/count-mismatch test, and no quantum-send fixture whose source
  access time is later than the modeled arrival. The current count-mismatch path
  constructs an error without throwing it.

## SYSV-005 — Verify backend capability boundaries

- **Covers:** SYS-007
- **Method:** test
- **Procedure:** Run dispatch, register, Gaussian projection, and background suites.
- **Environment / configuration:** Root tests; vector, Clifford, Monte Carlo, Gaussian, and operator representations.
- **Pass criterion:** Every cited supported case has its asserted state/observable result, while the cited dense-on-mixed unsupported observable throws.
- **Status:** implemented
- **Evidence:** [`register_interface_tests.jl`](../../../test/general/register_interface_tests.jl), [`representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl), [`observable_tests.jl`](../../../test/general/observable_tests.jl), [`project_traceout_gabs_homodyne_tests.jl`](../../../test/general/project_traceout_gabs_homodyne_tests.jl)
- **Nonconformance:** The support matrix is not baselined; coverage is partial, with no
  complete supported/unsupported fixtures across state, operation, observable,
  measurement, background, and non-instant capability classes.

## SYSV-006 — Verify distinct reusable Zoo surfaces

- **Covers:** SYS-008
- **Method:** test
- **Procedure:** Run the three Zoo API suites and representative protocol-control suites.
- **Environment / configuration:** Root tests without plotting.
- **Pass criterion:** Enumerated states lower and satisfy trace checks, circuit method arities match declared inputs, and protocol constructors/tags satisfy their surface assertions.
- **Status:** implemented
- **Evidence:** [`stateszoo_api_tests.jl`](../../../test/general/stateszoo_api_tests.jl), [`circuitzoo_api_tests.jl`](../../../test/general/circuitzoo_api_tests.jl), [`protocolzoo_surface_contracts_tests.jl`](../../../test/general/protocolzoo_surface_contracts_tests.jl)
- **Nonconformance:** No single test composes all three catalogs. State formulas/endpoints and CircuitZoo Node/Stringent variants are weak; `test/test_stateszoo_depolarized.jl` is orphaned.

## SYSV-007 — Verify public extension seams with local custom types

- **Covers:** SYS-009
- **Method:** test
- **Procedure:** Run custom tag and protocol logging-context overload tests.
- **Environment / configuration:** Root tests; custom types in the test module.
- **Pass criterion:** A custom tag is accepted through typed protocol/tag boundaries,
  and a custom protocol context overload dispatches and returns asserted fields.
- **Status:** implemented
- **Evidence:** [`abstract_tag_contract_tests.jl`](../../../test/general/abstract_tag_contract_tests.jl), [`logging_tests.jl`](../../../test/general/logging_tests.jl)
- **Nonconformance:** These are in-repository toy types, not independently packaged
  extensions. No custom numerical adapter, operation, model building block, complete
  protocol, or optional feature is exercised.

## SYSV-008 — Verify diagnostics, optional UI, and declared compatibility

- **Covers:** SYS-010, SYS-011
- **Method:** test
- **Procedure:** Run logging, plotting/PNG, cross-platform, downgrade, Aqua, JET, and docs actions.
- **Environment / configuration:** Declared Julia compatibility; general CI on Linux x64, macOS arm64, Windows x64; plotting/docs projects.
- **Pass criterion:** Core general tests pass on each configured OS; logging fields/types match assertions; optional rendering calls complete; Aqua/JET assertions hold; docs build completes in its configured environment.
- **Status:** implemented
- **Evidence:** [`ci.yml`](../../../.github/workflows/ci.yml), [`downgrade.yml`](../../../.github/workflows/downgrade.yml), [`logging_tests.jl`](../../../test/general/logging_tests.jl), [`show_png_tests.jl`](../../../test/plotting/show_png_tests.jl), [`aqua_tests.jl`](../../../test/general/aqua_tests.jl), [`jet_tests.jl`](../../../test/jet_tests.jl), [`pipeline.yml`](../../../.buildkite/pipeline.yml)
- **Nonconformance:** Plotting is smoke-only; logging is sampled; no clean core-only or
  partial-dependency activation matrix exists; docs are credentialed with no offline
  action; only general is cross-platform; the workspace lists missing
  `test/projects/examples`.
