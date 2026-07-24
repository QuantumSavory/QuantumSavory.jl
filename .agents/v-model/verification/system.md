# System Verification

These actions verify black-box behavior through public boundaries.

## SYSV-001 — Verify symbolic lowering and factorized registers

- **Covers:** SYS-001, SYS-002
- **Method:** test
- **Procedure:** Run symbolic Bell-state, two-body-operation, and parity fixtures in two
  representations, then couple selected factors of a heterogeneous register.
- **Environment / configuration:** Root tests with compatible representations and
  distinct slot declarations.
- **Pass criterion:** Both representations initialize and operate successfully and
  return the expected deterministic parity; every slot declaration remains observable,
  initialization leaves every explicit factor separately owned, and coupling makes only
  the touched factors share ownership.
- **Status:** implemented
- **Evidence:** [`observable_tests.jl`](../../../test/general/observable_tests.jl), [`representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl), [`register_interface_tests.jl`](../../../test/general/register_interface_tests.jl), [`apply_tests.jl`](../../../test/general/apply_tests.jl), [`project_traceout_tests.jl`](../../../test/general/project_traceout_tests.jl)
- **Nonconformance:** No fixture jointly checks both representations, all declarations,
  factor identities, and touched-only composition.

## SYSV-002 — Verify demand-driven monotonic time and backgrounds

- **Covers:** SYS-003
- **Method:** test
- **Procedure:** Advance distinct-time subsystems with supported backgrounds, inspect
  state/time, then request an earlier target.
- **Environment / configuration:** Root qubit, Clifford, and qumode tests.
- **Pass criterion:** Each selected subsystem evolves only for its own elapsed interval,
  every selected access time becomes the target, and the earlier-time request reports
  an error.
- **Status:** implemented
- **Evidence:** [`noninstant_and_backgrounds_qubit_tests.jl`](../../../test/general/noninstant_and_backgrounds_qubit_tests.jl), [`noninstant_and_backgrounds_clifford_tests.jl`](../../../test/general/noninstant_and_backgrounds_clifford_tests.jl), [`noninstant_and_backgrounds_qumode_tests.jl`](../../../test/general/noninstant_and_backgrounds_qumode_tests.jl)
- **Nonconformance:** Tests omit distinct elapsed intervals with every resulting time;
  backend coverage differs.

## SYSV-003 — Verify events, resources, metadata, and snapshots

- **Covers:** SYS-004, SYS-005
- **Method:** test
- **Procedure:** Exercise process, resource, wait, register-query, and message APIs with
  contention, all modes, and a snapshot across a yield.
- **Environment / configuration:** Deterministic root tests with duplicate metadata.
- **Pass criterion:** Contenders never overlap, the second acquires only after release,
  the waiter wakes no earlier than the change, and an unhandled process error reaches
  the caller. Register exact, wildcard, predicate, first, all, FIFO/FILO, and consuming
  modes return documented results; message stores return the first FIFO match, consume
  one match, and reject all-results mode. Observation changes neither store,
  consumption removes only its result, and a snapshot grants no reservation across a
  yield.
- **Status:** implemented
- **Evidence:** [`concurrentsim_helpers_tests.jl`](../../../test/general/concurrentsim_helpers_tests.jl), [`tags_and_queries_tests.jl`](../../../test/general/tags_and_queries_tests.jl), [`querywait_tests.jl`](../../../test/general/querywait_tests.jl), [`messagebuffer_tests.jl`](../../../test/general/messagebuffer_tests.jl), [`semaphore_2_tests.jl`](../../../test/general/semaphore_2_tests.jl), [`semaphore_3_tests.jl`](../../../test/general/semaphore_3_tests.jl), [`protocolzoo_entanglement_id_tests.jl`](../../../test/general/protocolzoo_entanglement_id_tests.jl)
- **Nonconformance:** Process-failure propagation and the complete register/message
  matrix, including rejected message all-results, are unasserted.

## SYSV-004 — Verify delayed classical and quantum transport

- **Covers:** SYS-006
- **Method:** test
- **Procedure:** On a three-node path, run directional direct transports, rejected and
  forwarded classical sends, and noisy correlated quantum transfer.
- **Environment / configuration:** Root tests with nonzero delays and transit background.
- **Pass criterion:** Direct classical and quantum deliveries occur no earlier than
  their configured directional delays; the nonadjacent direct request reports no
  channel, while explicit forwarding reaches the final incoming store; and quantum
  ownership moves to the empty destination while bidirectional ownership and remote
  correlation remain valid and a joint observable matches supported in-transit
  background evolution over the delay.
- **Status:** implemented
- **Evidence:** [`registernet_interface_tests.jl`](../../../test/general/registernet_interface_tests.jl), [`messagebuffer_tests.jl`](../../../test/general/messagebuffer_tests.jl), [`quantumchannel_tests.jl`](../../../test/general/quantumchannel_tests.jl)
- **Nonconformance:** Forwarding is untested. Quantum tests omit send/pre-arrival times,
  exact arrival, and in-transit backreferences; noisy cases check only end observables.
  Late source time can fail after ownership moves.

## SYSV-005 — Verify backend capability boundaries

- **Covers:** SYS-007
- **Method:** test
- **Procedure:** Execute supported and unsupported fixtures for every capability cell
  in the confirmed backend inventory.
- **Environment / configuration:** Root tests with discriminating physical results.
- **Pass criterion:** Every supported fixture produces its documented physical result;
  every designated unsupported fixture reports non-success and never substitutes
  different physical semantics.
- **Status:** implemented
- **Evidence:** [`register_interface_tests.jl`](../../../test/general/register_interface_tests.jl), [`representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl), [`observable_tests.jl`](../../../test/general/observable_tests.jl), [`quantummc_repr_tests.jl`](../../../test/general/quantummc_repr_tests.jl), [`project_traceout_gabs_homodyne_tests.jl`](../../../test/general/project_traceout_gabs_homodyne_tests.jl), [`noninstant_and_backgrounds_qubit_tests.jl`](../../../test/general/noninstant_and_backgrounds_qubit_tests.jl), [`noninstant_and_backgrounds_clifford_tests.jl`](../../../test/general/noninstant_and_backgrounds_clifford_tests.jl), [`noninstant_and_backgrounds_qumode_tests.jl`](../../../test/general/noninstant_and_backgrounds_qumode_tests.jl)
- **Nonconformance:** The inventory is unbaselined and fixtures are incomplete.

## SYSV-006 — Verify distinct reusable Zoo surfaces

- **Covers:** SYS-008
- **Method:** test
- **Procedure:** Execute one supported entry per Zoo independently and composed.
- **Environment / configuration:** Root tests on one compatible representation.
- **Pass criterion:** The state entry initializes a resource, the circuit entry acts
  immediately on selected resources, and the protocol schedules as a resumable process,
  both independently and in the composed scenario.
- **Status:** implemented
- **Evidence:** [`stateszoo_api_tests.jl`](../../../test/general/stateszoo_api_tests.jl), [`circuitzoo_api_tests.jl`](../../../test/general/circuitzoo_api_tests.jl), [`protocolzoo_surface_contracts_tests.jl`](../../../test/general/protocolzoo_surface_contracts_tests.jl)
- **Nonconformance:** API suites are separate; none asserts all three in one scenario.

## SYSV-007 — Verify public third-party extension seams

- **Covers:** SYS-009
- **Method:** test
- **Procedure:** Invoke external fixtures for every confirmed extension class through
  normal product operations.
- **Environment / configuration:** Clean external packages against the pinned revision.
- **Pass criterion:** Normal product operations select every external implementation
  through the same boundary as built-ins, each returns its documented result, and no
  QuantumSavory core-source change is required.
- **Status:** implemented
- **Evidence:** [`abstract_tag_contract_tests.jl`](../../../test/general/abstract_tag_contract_tests.jl), [`logging_tests.jl`](../../../test/general/logging_tests.jl)
- **Nonconformance:** Only in-repository tag/logging types exist; no external numerical
  adapter, operation, model, protocol, or optional feature is tested.
