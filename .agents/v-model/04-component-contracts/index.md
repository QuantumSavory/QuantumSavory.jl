# Component Contracts

These shards retain only non-obvious invariants, preconditions, postconditions, and
semantic distinctions needed to implement or verify the subsystem contracts.

- [Core simulation contracts](core-simulation.md): `CMP-001` through `CMP-006` and
  `CMP-009`
- [Network and transport contracts](network-control.md): `CMP-007` and `CMP-008`
- [Zoo and extension contracts](zoos-extensions.md): `CMP-010` through `CMP-013`

The verification action definitions are authored separately. Every contract below
reserves its mapped `UNITV` action ID.
