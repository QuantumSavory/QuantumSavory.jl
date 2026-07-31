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

The current `simulation_log_context(sim)` helper supplies `sim_time::Float64` and
`sim_process_id::Union{UInt,Nothing}`. `protocol_log_context(prot)` adds a protocol
symbol and ordered node tuple. These helpers keep live protocol, network, register,
message, and query objects out of base context, but their fields are implementation
details rather than stable schemas.

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

## Public-surface mismatch

`simulation_log_context` and `protocol_log_context` remain exported even though
maintainer-confirmed intent treats logging-context hooks as internal rather than
third-party extension APIs. Human prose and their docstrings now say so, but source
exports and checked-in examples that call them still need reconciliation under SYS-009
and SYS-012. This does not alter the stability of `LOG_GROUPS`.
