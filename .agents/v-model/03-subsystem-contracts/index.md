# Subsystem and Interface Contracts

These shards specify logical responsibilities, state and error semantics, and boundary
contracts without fixing source-file or package topology.

- [Symbolic lowering, events, and backend contracts](lowering-events-backends.md):
  `SUB-001`, `SUB-004`, and `SUB-010`
- [Register state, operations, metadata, and inspection](register-state-metadata.md):
  `SUB-002`, `SUB-003`, `SUB-005`, `SUB-006`, and `SUB-015`
- [Network and transport contracts](network-control.md): `SUB-007` through `SUB-009`
  and `SUB-016`
- [Zoo and extension contracts](zoos-extensions.md): `SUB-011` through `SUB-014`

The verification action definitions are authored separately. Every contract below
reserves its mapped `INTV` action ID.
