# Verification and Acceptance

These records map durable repository evidence to the four specification layers. A
status of `implemented` means the action exists but this documentation pass did not
capture current, complete execution evidence. Open only the shard needed for the
requirement under review.

- [Acceptance verification](acceptance.md): open for stakeholder-facing operational
  demonstrations.
- [System verification](system.md): open for black-box public behavior, supported
  operations, transport, catalogs, and extension seams.
- [System quality and inspection verification](system-quality.md): open for diagnostics,
  compatibility, reproducibility, and inspection behavior.
- [Core integration verification](integration-core.md): open for symbolic/register,
  event, metadata, protocol-revalidation, and backend boundaries.
- [Network, Zoo, and extension integration verification](integration-network-zoo.md):
  open for transport, catalog, protocol, activation, and inspection boundaries.
- [Core component verification](component-core.md): open for focused register, time,
  metadata, notification, and backend invariants.
- [Network, Zoo, and extension component verification](component-network-zoo.md): open
  for focused transport, catalog, protocol, logging, and activation invariants.

Known evidence limitations are recorded as nonconformances; they are not implicit
waivers. Transient console output does not belong in these records.
