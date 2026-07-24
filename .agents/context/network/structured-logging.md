# Structured Logging

- **Context need:** Reference
- **Open when:** Adding, filtering, or reviewing diagnostic records and their simulation context.
- **Do not open when:** Work has no logging, observability, or optional-inspection impact.
- **Related specification IDs:** SYS-010, SUB-014, CMP-013
- **Review when:** `LOG_GROUPS`, context helpers, emitted record fields, or logger-facing documentation changes.

## Logging contract

QuantumSavory uses Julia logging records with subsystem groups. `LOG_GROUPS` declares
five stable group symbols: `backend`, `simulation`, `protocol`, `network`, and
`visualization`. Use the exported values in `_group`; do not duplicate literal symbols
throughout new code. Group filtering is the supported coarse selection mechanism.

`simulation_log_context(sim)` supplies the simulation time and active-process identity.
Protocol code extends that context with protocol identity through its helper. Merge
these fields into structured key-value records rather than embedding all context in a
human sentence. Records should still have a concise message that makes unfiltered
output understandable.

The groups are explicitly described as stable by source and human documentation.
Individual event symbols, messages, levels, and field vocabularies are less settled.
The logging tests cover representative backend, protocol, and network events and group
filtering; they do not enumerate every emitter as a frozen schema. Consumers should
treat the event vocabulary as sampled unless the specific event has a dedicated test
and documentation statement.

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

## Unresolved questions

- Which event names and fields, if any, should become versioned public schemas?
- Should every subsystem receive representative logging contract tests?
