# System Verification

## SYSV-001 — Verify symbolic lowering and factorized registers

- **Covers:** SYS-001, SYS-002
- **Method:** test
- **Procedure:** Run Bell-state operation and parity fixtures in two representations;
  couple selected factors of a heterogeneous register.
- **Environment / configuration:** Tests with compatible representations and distinct
  slot declarations.
- **Pass criterion:** Both representations return expected parity; all slot
  declarations remain observable, initialization keeps explicit factors
  separately owned, and coupling shares only touched factors.
- **Status:** implemented
- **Evidence:** [`observable_tests.jl`](../../../test/general/observable_tests.jl), [`representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl), [`register_interface_tests.jl`](../../../test/general/register_interface_tests.jl), [`apply_tests.jl`](../../../test/general/apply_tests.jl), [`project_traceout_tests.jl`](../../../test/general/project_traceout_tests.jl)
- **Nonconformance:** No fixture jointly checks representations, declarations, factor
  identities, and touched-only composition.

## SYSV-002 — Verify local monotonic time, synchronization, and backgrounds

- **Covers:** SYS-003
- **Method:** test
- **Procedure:** Advance independent subsystems from distinct local times under
  supported backgrounds, then make selected subsystems interact.
- **Environment / configuration:** Root qubit, Clifford, and qumode tests.
- **Pass criterion:** Independent slots evolve only over their forward elapsed
  intervals; interaction advances selected slots to its time, synchronizes their local
  times, and leaves others unchanged.
- **Status:** implemented
- **Evidence:** [`noninstant_and_backgrounds_qubit_tests.jl`](../../../test/general/noninstant_and_backgrounds_qubit_tests.jl), [`noninstant_and_backgrounds_clifford_tests.jl`](../../../test/general/noninstant_and_backgrounds_clifford_tests.jl), [`noninstant_and_backgrounds_qumode_tests.jl`](../../../test/general/noninstant_and_backgrounds_qumode_tests.jl)
- **Nonconformance:** Tests do not jointly assert local intervals, interaction
  synchronization, and untouched times; backend coverage differs.

## SYSV-003 — Verify events, resources, metadata, and snapshots

- **Covers:** SYS-004, SYS-005
- **Method:** test
- **Procedure:** Exercise resource contention, timeouts, change waits, register/message
  queries, equal-time independence, a causal dependency, and a snapshot across a yield.
- **Environment / configuration:** Controlled root tests with duplicate metadata.
- **Pass criterion:** Resource owners never overlap; a blocked contender acquires only
  after release. A timeout resumes no earlier than its scheduled simulated time; a
  change waiter wakes no earlier than its change; process errors reach the caller.
  Register exact, wildcard, predicate, first, all, FIFO/FILO, and consuming modes return
  documented results; FILO is default. Messages return and consume the first FIFO match
  and reject all-results mode. `query_wait` neither consumes nor locks,
  `querydelete_wait!` consumes one, and snapshots grant no reservation across a yield.
  Independent equal-time actions have no asserted order; dependencies are respected.
- **Status:** implemented
- **Evidence:** [`concurrentsim_helpers_tests.jl`](../../../test/general/concurrentsim_helpers_tests.jl), [`tags_and_queries_tests.jl`](../../../test/general/tags_and_queries_tests.jl), [`querywait_tests.jl`](../../../test/general/querywait_tests.jl), [`messagebuffer_tests.jl`](../../../test/general/messagebuffer_tests.jl), [`semaphore_2_tests.jl`](../../../test/general/semaphore_2_tests.jl), [`semaphore_3_tests.jl`](../../../test/general/semaphore_3_tests.jl), [`protocolzoo_entanglement_id_tests.jl`](../../../test/general/protocolzoo_entanglement_id_tests.jl)
- **Nonconformance:** No fixture jointly covers failures, full query matrices and
  defaults, absence of an implicit lock, rejected all-results, and equal-time
  independence.

## SYSV-004 — Verify delayed classical and quantum transport

- **Covers:** SYS-006
- **Method:** test
- **Procedure:** On a three-node path, run directional direct transports, rejected and
  forwarded classical sends, noisy correlated quantum transfer under valid source
  timing, and receipt into an occupied destination.
- **Environment / configuration:** Root tests with nonzero delays and transit background.
- **Pass criterion:** Direct classical and quantum deliveries respect directional
  delays; a nonadjacent direct request reports no
  channel, while explicit forwarding reaches the final incoming store; and quantum
  ownership moves to the empty destination while bidirectional ownership and remote
  correlation remain valid and a joint observable matches supported in-transit
  background evolution over the delay. Occupied receipt reports failure, discards the
  transmitted state, and emits a warning.
- **Status:** implemented
- **Evidence:** [`registernet_interface_tests.jl`](../../../test/general/registernet_interface_tests.jl), [`messagebuffer_tests.jl`](../../../test/general/messagebuffer_tests.jl), [`quantumchannel_tests.jl`](../../../test/general/quantumchannel_tests.jl)
- **Nonconformance:** Forwarding is untested. Quantum tests omit send/pre-arrival times,
  exact arrival, and in-transit backreferences; noisy cases check only end observables.
  The occupied-destination path emits no warning. Source access later than modeled
  arrival can fail after ownership moves; that configuration is outside valid use.

## SYSV-005 — Verify representation defaults, capabilities, and promotion

- **Covers:** SYS-007
- **Method:** test
- **Procedure:** Exercise default construction and all capability classes with general,
  specialized, mixed, and explicitly selected representations; request automatic and
  approximate promotion, explicit twirling, and no-method dispatch.
- **Environment / configuration:** Root tests with `QuantumOpticsRepr`,
  `QuantumMCRepr`, `CliffordRepr`, `GabsRepr`, discriminating physical results, and
  captured call-site warnings.
- **Pass criterion:** Qubit and qumode default to `QuantumOpticsRepr`; Clifford and Gabs
  are opt-in specialized representations, and Monte Carlo is a general peer. Supported
  requests return their documented physical result. A specialized or mixed request
  lacking direct support promotes across every capability class to a compatible common
  general representation, carries approximation parameters, and warns once per call
  site with only initial and final representation names. A supported general input plus
  explicit configured twirling object converts to the requested specialized
  representation with the object's declared semantics; without that object it remains
  general. If no path applies, dispatch retains `MethodError`; a hint may supplement
  it.
- **Status:** planned
- **Evidence:** [`register_interface_tests.jl`](../../../test/general/register_interface_tests.jl), [`representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl), [`observable_tests.jl`](../../../test/general/observable_tests.jl), [`quantummc_repr_tests.jl`](../../../test/general/quantummc_repr_tests.jl), [`project_traceout_gabs_homodyne_tests.jl`](../../../test/general/project_traceout_gabs_homodyne_tests.jl), [`noninstant_and_backgrounds_qubit_tests.jl`](../../../test/general/noninstant_and_backgrounds_qubit_tests.jl), [`noninstant_and_backgrounds_clifford_tests.jl`](../../../test/general/noninstant_and_backgrounds_clifford_tests.jl), [`noninstant_and_backgrounds_qumode_tests.jl`](../../../test/general/noninstant_and_backgrounds_qumode_tests.jl)
- **Nonconformance:** Defaults, `QuantumOpticsRepr` cutoff configuration, and isolated
  conversions exist, but no complete matrix does. Uniform promotion and propagation of
  configured approximation settings, twirling objects, and the common warning policy
  are unimplemented.

## SYSV-006 — Verify the complete public Zoo surfaces

- **Covers:** SYS-008
- **Method:** test
- **Procedure:** Inventory and execute all public Zoo entries independently, then
  compose one from each Zoo in a user-oriented example.
- **Environment / configuration:** Generated API docs, root tests in each entry's
  documented compatible representation subset, and examples project.
- **Pass criterion:** Every public state documents its constructor parameters,
  exposes expected-value introspection, and initializes with documented normalized or
  weighted semantics. Every public circuit is documented, exposes consistent features
  including arity, and acts immediately. Every public protocol family—including core,
  Switch, QTCP, and MBQC—documents every constructor parameter and runs as a resumable
  process. Each has API-reference and user-example coverage; internal helpers are absent.
- **Status:** implemented
- **Evidence:** [`stateszoo_api_tests.jl`](../../../test/general/stateszoo_api_tests.jl), [`circuitzoo_api_tests.jl`](../../../test/general/circuitzoo_api_tests.jl), [`protocolzoo_surface_contracts_tests.jl`](../../../test/general/protocolzoo_surface_contracts_tests.jl)
- **Nonconformance:** Existing API suites do not derive a complete public inventory or
  validate documentation and examples. State representation/range coverage, circuit
  feature consistency, and protocol constructor documentation—especially QTCP and
  MBQC—are incomplete. Internal `_log`/`_backlog` storage remains accepted by generated
  protocol keyword-constructor paths.

## SYSV-007 — Verify the public and SemVer-protected boundary

- **Covers:** SYS-009
- **Method:** test
- **Procedure:** Build generated docs; inventory every exported, reexported, or `public`
  QuantumSavory name and its provenance; compare public tag schemas with the compatible
  baseline; and inspect internals and tutorial-local helpers.
- **Environment / configuration:** Revision under review and the previous
  SemVer-compatible public-surface manifest; dependency internals that QuantumSavory
  does not expose remain out of scope.
- **Pass criterion:** Every public API, including chosen reexports, appears in generated
  prose and is exported or marked `public`; documented unexported APIs use `public`.
  Internal lowering, backend, lifecycle, logging, Zoo-subtype, activation, and tutorial
  helpers are not public. Public tag names and ordered layouts match the compatible
  baseline. Other incompatibilities require a breaking version; no preceding
  deprecation release or stable representation default is required.
- **Status:** planned
- **Evidence:** [`API.md`](../../../docs/src/API.md), [`API_StatesZoo.md`](../../../docs/src/API_StatesZoo.md), [`API_CircuitZoo.md`](../../../docs/src/API_CircuitZoo.md), [`API_ProtocolZoo.md`](../../../docs/src/API_ProtocolZoo.md), [`standard_protocol_tags.md`](../../../docs/src/standard_protocol_tags.md), [`abstract_tag_contract_tests.jl`](../../../test/general/abstract_tag_contract_tests.jl)
- **Nonconformance:** No public-surface or compatible-schema manifest exists. Documented
  unexported inspection/discovery functions and qualified Zoo module bindings lack
  `public` declarations, while internal backend/protocol/logging hooks remain exported;
  public/internal classification is not mechanically enforced.
