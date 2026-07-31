# Structured Logging

- **Context need:** Reference
- **Open when:** Adding, filtering, or reviewing diagnostic records and their simulation context.
- **Do not open when:** Work has no logging, observability, or optional-inspection impact.
- **Related specification IDs:** SYS-009, SYS-010, SUB-014, CMP-013
- **Review when:** `LOG_GROUPS`, context helpers, emitted record fields, or logger-facing documentation changes.

## Logging contract

QuantumSavory uses Julia logging records with subsystem groups. `LOG_GROUPS` declares
five stable group symbols: `backend`, `simulation`, `protocol`, `network`, and
`visualization`. Use the exported values in `_group`; do not duplicate literal symbols
throughout new code. Group filtering is the supported coarse selection mechanism.

The exported `simulation_log_context(sim)` and `protocol_log_context(prot)` helpers are
supported extension points for constructing records. The first currently supplies
simulation time and process identity; the second adds protocol identity and an ordered
node tuple and should be overloaded for custom `AbstractProtocol` layouts. Keep live
protocol, network, register, message, and query objects out of base context.

Only the five groups are stable. Messages, levels, event symbols, fields, semantic
field details, ordering, presence, and event sequences may all change without a
breaking release. Logging tests cover representative backend, protocol, and network
records plus group filtering; they are implementation evidence, not frozen schemas.

Choose level according to operational meaning: routine state transitions should remain
filterable diagnostics, recoverable inconsistencies should carry enough identifiers
for reconstruction, and exceptions should not be replaced by logs where the caller
needs failure propagation. Avoid logging backend state payloads by default; they can be
large and may make simulation output nondeterministic.

Optional visualization or interactive extensions may emit the visualization group, but
their activation must stay isolated behind Julia weak dependencies. Core logging code
must remain loadable without those packages.

## Anchors

- **Source:** [`src/logging.jl`](../../../src/logging.jl), [`src/messagebuffer.jl`](../../../src/messagebuffer.jl), and [`src/ProtocolZoo/ProtocolZoo.jl`](../../../src/ProtocolZoo/ProtocolZoo.jl) — group/context definitions and representative emitters.
- **Docs:** [`docs/src/architecture.md`](../../../docs/src/architecture.md) and [`docs/src/API_ProtocolZoo.md`](../../../docs/src/API_ProtocolZoo.md) — public structured-logging convention.
- **Test:** [`test/general/logging_tests.jl`](../../../test/general/logging_tests.jl) and [`test/general/observable_tests.jl`](../../../test/general/observable_tests.jl) — group filtering, contexts, and sampled records.

Supporting the context helpers does not freeze their returned field schema. Consumers
that require SemVer-stable filtering should select by `LOG_GROUPS`; custom emitters
should splat the helper result and add event-specific metadata rather than depend on an
exact field inventory.
