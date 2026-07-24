# Integration Verification

## INTV-001 — Verify register state, factorization, operation, and time integration

- **Covers:** SUB-001, SUB-002, SUB-003
- **Method:** test
- **Procedure:** Run register interface, representation dispatch, apply, observable, and project/traceout suites.
- **Environment / configuration:** Root test environment with the supported qubit representations used by the fixtures.
- **Pass criterion:** Symbolic operations/observables return asserted backend results; cited state references compose and clear consistently; destructive operations unassign targets; rewind requests throw.
- **Status:** implemented
- **Evidence:** [`register_interface_tests.jl`](../../../test/general/register_interface_tests.jl), [`representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl), [`observable_tests.jl`](../../../test/general/observable_tests.jl), [`project_traceout_tests.jl`](../../../test/general/project_traceout_tests.jl), [`traceout_tests.jl`](../../../test/general/traceout_tests.jl), [`noninstant_and_backgrounds_qubit_tests.jl`](../../../test/general/noninstant_and_backgrounds_qubit_tests.jl)
- **Nonconformance:** No test directly checks post-observable owner identities or an incompatible symbolic-lowering fixture; the matrix is partial.

## INTV-002 — Verify event scheduling against wait and notification semantics

- **Covers:** SUB-004, SUB-006
- **Method:** test
- **Procedure:** Run ConcurrentSim helper, query-wait, semaphore, and message-buffer timing suites.
- **Environment / configuration:** Root test environment with deterministic simulated timestamps and concurrent resumable processes.
- **Pass criterion:** Matching waits return only matching items, non-consuming waits preserve them, consuming waits allocate one item per waiter, and change notifications wake in the asserted order without losing queued buffer arrivals.
- **Status:** implemented
- **Evidence:** [`concurrentsim_helpers_tests.jl`](../../../test/general/concurrentsim_helpers_tests.jl), [`querywait_tests.jl`](../../../test/general/querywait_tests.jl), [`semaphore_2_tests.jl`](../../../test/general/semaphore_2_tests.jl), [`semaphore_3_tests.jl`](../../../test/general/semaphore_3_tests.jl), [`messagebuffer_tests.jl`](../../../test/general/messagebuffer_tests.jl)
- **Nonconformance:** No test asserts process-failure propagation or absence of partial paired acquisition while blocked; schedules are selected cases.

## INTV-003 — Verify protocols consume and revalidate shared metadata

- **Covers:** SUB-005, SUB-013
- **Method:** test
- **Procedure:** Run tag/query plus protocol stale-query, tracker-lock, and pair-identity suites.
- **Environment / configuration:** Root test environment on deterministic small networks with injected stale metadata.
- **Pass criterion:** Query order and deletion match asserted tag identities; protocol consumers reject stale matches, preserve required locks through update, and do not mutate a fresh pair that reuses an old slot tuple.
- **Status:** implemented
- **Evidence:** [`tags_and_queries_tests.jl`](../../../test/general/tags_and_queries_tests.jl), [`protocolzoo_entanglement_consumer_stale_query_tests.jl`](../../../test/general/protocolzoo_entanglement_consumer_stale_query_tests.jl), [`protocolzoo_entanglement_tracker_lock_gap_tests.jl`](../../../test/general/protocolzoo_entanglement_tracker_lock_gap_tests.jl), [`protocolzoo_entanglement_id_tests.jl`](../../../test/general/protocolzoo_entanglement_id_tests.jl)
- **Nonconformance:** No generated comparison covers every indexed query against a canonical scan; some consumer/grid fixtures can pass vacuously.

## INTV-004 — Verify one network domain and direct delayed transports

- **Covers:** SUB-007, SUB-008, SUB-009
- **Method:** test
- **Procedure:** Run RegisterNet construction/delay, metadata access, message-buffer, and quantum-channel suites.
- **Environment / configuration:** Root test environment on scalar- and per-direction-delay graph fixtures.
- **Pass criterion:** The cited net/register/message store share a tracker; directional delays match configuration; classical arrival time is asserted; quantum take transfers ownership and applies asserted transit noise.
- **Status:** implemented
- **Evidence:** [`concurrentsim_helpers_tests.jl`](../../../test/general/concurrentsim_helpers_tests.jl), [`registernet_interface_tests.jl`](../../../test/general/registernet_interface_tests.jl), [`registernet_metadata_access_tests.jl`](../../../test/general/registernet_metadata_access_tests.jl), [`messagebuffer_tests.jl`](../../../test/general/messagebuffer_tests.jl), [`quantumchannel_tests.jl`](../../../test/general/quantumchannel_tests.jl)
- **Nonconformance:** No focused test covers explicit multi-hop classical forwarding or malformed network/register counts; forwarding is only exercised indirectly by protocols/examples.

## INTV-005 — Verify backend capability dispatch in composed operations

- **Covers:** SUB-010
- **Method:** test
- **Procedure:** Run dispatch, Monte Carlo lifecycle, Gaussian homodyne, and backend background suites.
- **Environment / configuration:** Root test environment with vector, operator, Clifford, Monte Carlo, and Gaussian dependencies.
- **Pass criterion:** Each cited supported state/operation pair remains on or deliberately exits its asserted manifold and produces the asserted observable or reference-state result.
- **Status:** implemented
- **Evidence:** [`representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl), [`quantummc_repr_tests.jl`](../../../test/general/quantummc_repr_tests.jl), [`project_traceout_gabs_homodyne_tests.jl`](../../../test/general/project_traceout_gabs_homodyne_tests.jl), [`noninstant_and_backgrounds_clifford_tests.jl`](../../../test/general/noninstant_and_backgrounds_clifford_tests.jl)
- **Nonconformance:** Coverage is not a full backend-by-operation matrix, and unsupported combinations lack a uniform tested error contract.

## INTV-006 — Verify state and circuit catalog entries through register execution

- **Covers:** SUB-011, SUB-012
- **Method:** test
- **Procedure:** Run StateZoo API and CircuitZoo swap, fusion, superdense, and purification suites.
- **Environment / configuration:** Root test environment with symbolic lowering and the backends selected by each fixture.
- **Pass criterion:** Cited states accept declared good parameters and lower successfully; cited circuit calls satisfy asserted measurement, fidelity, and destructive-slot effects.
- **Status:** implemented
- **Evidence:** [`stateszoo_api_tests.jl`](../../../test/general/stateszoo_api_tests.jl), [`circuitzoo_ent_swap_tests.jl`](../../../test/general/circuitzoo_ent_swap_tests.jl), [`circuitzoo_fusion_tests.jl`](../../../test/general/circuitzoo_fusion_tests.jl), [`circuitzoo_superdense_tests.jl`](../../../test/general/circuitzoo_superdense_tests.jl), [`circuitzoo_purification_tests.jl`](../../../test/general/circuitzoo_purification_tests.jl)
- **Nonconformance:** State formulas/range endpoints are weak; the depolarized file is orphaned; no circuit time-advance assertion exists; Node/Stringent return coverage is incomplete.

## INTV-007 — Verify asynchronous protocol composition and stale-state recovery

- **Covers:** SUB-013
- **Method:** test
- **Procedure:** Run entangler/tracker/swapper/consumer/switch, QTCP, MBQC, stale-query, and cleanup suites.
- **Environment / configuration:** Root test environment on deterministic chain/grid fixtures and injected stale-state cases.
- **Pass criterion:** Representative protocols exchange asserted tags, consume reciprocal tags once, preserve pair identity, release stale-case locks, and produce asserted QTCP counts and MBQC stabilizer/tag results.
- **Status:** implemented
- **Evidence:** [`protocolzoo_entangler_tests.jl`](../../../test/general/protocolzoo_entangler_tests.jl), [`protocolzoo_entanglement_consumer_tests.jl`](../../../test/general/protocolzoo_entanglement_consumer_tests.jl), [`protocolzoo_entanglement_id_tests.jl`](../../../test/general/protocolzoo_entanglement_id_tests.jl), [`protocolzoo_switch_tests.jl`](../../../test/general/protocolzoo_switch_tests.jl), [`protocolzoo_qtcp_tests.jl`](../../../test/general/protocolzoo_qtcp_tests.jl), [`protocolzoo_mbqc_tests.jl`](../../../test/general/protocolzoo_mbqc_tests.jl)
- **Nonconformance:** QTCP does not assert delivered fidelity/corrections; MBQC endpoint evidence permits either one of two tags in one case; some consumer/grid assertions are weak or conditional.

## INTV-008 — Verify optional inspection activation and structured logging

- **Covers:** SUB-014
- **Method:** test
- **Procedure:** Run general logging/HTML/InteractiveUtils tests, then plotting-project Cairo, GL, PNG, and doctest actions.
- **Environment / configuration:** Core root environment followed by the isolated plotting project with CairoMakie/GLMakie.
- **Pass criterion:** Structured contexts contain asserted primitive fields and early filtering avoids evaluation; optional extension calls load in their configured projects and all cited render/show calls complete.
- **Status:** implemented
- **Evidence:** [`logging_tests.jl`](../../../test/general/logging_tests.jl), [`interactiveutils_tests.jl`](../../../test/general/interactiveutils_tests.jl), [`cairo_tests.jl`](../../../test/plotting/cairo_tests.jl), [`gl_tests.jl`](../../../test/plotting/gl_tests.jl), [`show_png_tests.jl`](../../../test/plotting/show_png_tests.jl)
- **Nonconformance:** Plotting is smoke-only; logging is sampled; no absent/partial/full dependency matrix or unavailable-call diagnostic is tested in clean environments.
