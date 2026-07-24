# Subsystem and Interface Contracts

These shards specify logical responsibilities, state and error semantics, and boundary
contracts without fixing source-file or package topology.

- [Core simulation contracts](core-simulation.md): `SUB-001` through `SUB-006` and
  `SUB-010`
- [Network and transport contracts](network-control.md): `SUB-007` through `SUB-009`
- [Zoo and extension contracts](zoos-extensions.md): `SUB-011` through `SUB-014`

The verification action definitions are authored separately. Every contract below
reserves its mapped `INTV` action ID.
