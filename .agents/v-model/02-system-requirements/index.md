# System Requirements

These requirements specify observable capabilities and boundaries. Implementation
packages, files, and algorithms are intentionally excluded from their normative text.

- [Core and simulation requirements](core-simulation.md): `SYS-001` through
  `SYS-005` and `SYS-007`
- [Network and control requirements](network-control.md): `SYS-006` and `SYS-013`
- [Zoo, extension, and observability requirements](zoos-extensions-observability.md):
  `SYS-008` through `SYS-012`

## System-level limitations

The exception, compatibility, reproducibility, external-service, and budget limitations
in the [profile index](../index.md) apply throughout. Valid timed workflows request
nondecreasing local times; behavior after an exception is not a continuation contract.
Backend promotion, explicit specialization, public API marking, and parts of the Zoo
support bar are aspirational requirements with current nonconformances.
