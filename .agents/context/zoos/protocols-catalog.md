# Protocols Catalog

- **Context need:** Reference
- **Open when:** Choosing among shipped resumable protocols or assessing their current implementation status.
- **Do not open when:** Adding a protocol, selecting an immediate circuit, or changing transport internals.
- **Review when:** ProtocolZoo includes/exports, protocol families, or known implementation gaps change.

## Protocol families

ProtocolZoo contains callable `AbstractProtocol` values run as ConcurrentSim processes.
Constructor shorthands derive the simulation from the supplied `RegisterNet`; callers
should not maintain a separate clock. Use the human API for fields and signatures.

The core family covers link entanglement generation (`EntanglerProt`), swapping
(`SwapperProt`), counterpart propagation (`EntanglementTracker`), consumption
(`EntanglementConsumer`), and age-based cleanup (`CutoffProt`). These protocols
coordinate register resources and fixed metadata tags across yields.

`switches.jl` adds discrete switch scheduling and request tags. `qtcp.jl` adds flows,
datagrams, link requests/replies, and end/network/link controllers. `mbqc.jl` adds graph
state construction, graph-to-resource mapping, purification measurements, and tracking.
All three are part of ProtocolZoo, not separate external zoos.

`AspenNet` is an internal experimental submodule for two synchronized photon sources
and one heralding hub. It uses bosonic modes with a four-photon Fock cutoff,
buffered generation, local Fock-basis measurements reduced to vacuum/nonvacuum,
and balanced beamsplitter interference at the hub. A herald requires a first-output
click and second-output vacuum, fixing the Bell phase. Omit local measurement
processes to retain the heralded memory modes. The hub records
and confirms only periods with an arriving mode, including an arriving vacuum mode;
periods with no arrivals are skipped. The example in
[`examples/aspen_net/`](../../../examples/aspen_net/) records local and hub histories;
the module is not public and has no documentation website entry.
Both examples use reflectivity 0.1 for more frequent heralds at lower Bell fidelity;
the module docstring explains the tradeoff and measurement outcomes.
Its second example runs one shared simulation behind a Bonito/WGLMakie dashboard
and an Oxygen API, with explicit startup and shutdown for its tasks and servers.
`/api/status` exposes the modeled hardware's shared-clock time and settings;
clients choose their own future work intervals. `/api/simulation/status` exposes
wall-clock pacing. The dashboard labels these snapshots Hardware and Simulation.
`/api/simulation/config` returns the twin's startup configuration, including
overrides, reused on reset. Its initial pacing setting is separate from current
pacing.
`/api/simulation/run_scenario` accepts `scenario=run_samples_until_reset` and
optional `sleep_seconds`. It schedules both configured sources at the next buffer
boundary through reset, with schedule and pacing changes under the same guard.
Overlapping work is rejected before either source or pacing changes; reset clears
the scenario's work.
Dashboard detector-click count heatmaps join the three measurement histories by
buffer period and omit periods missing any of those records. Analysis titles count
each completed buffer period with at least one scheduled source, including periods
producing no photon. The both-source/no-hub count overlaps the per-source pending counts.
At the configured reset time (100000 by default), the example replaces its
simulation, clears histories, counts, and pending work, and returns sources to idle
while keeping servers and browser sessions connected.
The pacing API sets the wall-clock delay after each simulation step; this setting
persists across resets.

Every documented and public family is intended for long-term support; implementation
completeness still varies. QTCP contains unresolved drop detection, correction, and
timeout work. MBQC currently uses contiguous node-number arithmetic in routing/mapping
code, so it must not be assumed correct for arbitrary graph labels. Entanglement pair
identifiers can collide with the zero sentinel under the current combination scheme.
Switch tests cover several stale-match and reciprocal-delete races, but do not prove
every scheduler policy.

The supported authoring surface includes the documented `AbstractProtocol` callable
pattern, virtual-edge capability, logging-context overload, and the
`protocol_catalog_metadata` opt-in trait, so external libraries can define reusable
protocols in the same style as ProtocolZoo. The InteractiveUtils catalog discovers
loaded public types recursively and validates attachment roles against documented
constructor fields. Public protocol constructors generally use DocStringExtensions
field tables. Configuration fields are supported constructor inputs; runtime
bookkeeping fields such as `_log` and `_backlog` are explicitly internal and their
storage types may change.

## Anchors

- **Source:** [`src/ProtocolZoo/ProtocolZoo.jl`](../../../src/ProtocolZoo/ProtocolZoo.jl), [`src/ProtocolZoo/switches.jl`](../../../src/ProtocolZoo/switches.jl), [`src/ProtocolZoo/qtcp.jl`](../../../src/ProtocolZoo/qtcp.jl), and [`src/ProtocolZoo/mbqc.jl`](../../../src/ProtocolZoo/mbqc.jl) — core and specialist families.
- **Docs:** [`docs/src/API_ProtocolZoo.md`](../../../docs/src/API_ProtocolZoo.md) and [`docs/src/zoos_as_building_blocks.md`](../../../docs/src/zoos_as_building_blocks.md) — public catalog and reuse guidance.
- **Test:** [`test/general/protocolzoo_surface_contracts_tests.jl`](../../../test/general/protocolzoo_surface_contracts_tests.jl), [`test/general/protocolzoo_switch_tests.jl`](../../../test/general/protocolzoo_switch_tests.jl), [`test/general/protocolzoo_qtcp_tests.jl`](../../../test/general/protocolzoo_qtcp_tests.jl), and [`test/general/protocolzoo_mbqc_tests.jl`](../../../test/general/protocolzoo_mbqc_tests.jl) — family surfaces.

## Known gaps

- QTCP has incomplete drop, correction, and timeout behavior.
- MBQC assumes contiguous node labels in several paths.
- Combined entanglement identifiers can collide with the zero sentinel.
- The documented qualified `promponas_bruteforce_choice` switch selector and Zoo module
  bindings lack `public` declarations.
- Generated constructor-reference coverage is not mechanically audited. Runtime
  `_log`/`_backlog` storage remains accepted by generated `@kwdef` constructor paths and
  is read by examples even though its concrete type is not a supported interface.
