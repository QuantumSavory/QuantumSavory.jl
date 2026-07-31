# Verification and Acceptance

These records map durable repository evidence to the four specification layers of the
living, aspirational product contract. Actions assess the revision under review; they
do not limit the contract to one historical commit. A status of `implemented` means an
action artifact exists but complete current evidence is absent. Promotion to `passing`
requires every criterion clause, applicable supported environment, public
documentation, user example, and focused test to be evidenced in a
maintainer-reviewed merge.

- [Acceptance verification](acceptance.md): open for stakeholder-facing operational
  demonstrations.
- [System verification](system.md): open for black-box public behavior, representation
  policy, transport, catalogs, and SemVer boundaries.
- [System quality and inspection verification](system-quality.md): open for
  diagnostics, compatibility, documentation, examples, and inspection behavior.
- [Core integration verification](integration-core.md): open for symbolic/register,
  event, metadata, protocol-revalidation, and backend boundaries.
- [Network, Zoo, and built-in extension integration](integration-network-zoo.md):
  open for transport, catalog, protocol, activation, and inspection boundaries.
- [Core component verification](component-core.md): open for focused register, time,
  metadata, notification, and backend invariants.
- [Network, Zoo, and extension component verification](component-network-zoo.md): open
  for focused transport, catalog, protocol, logging, and activation invariants.

Known evidence limitations are nonconformances, not implicit waivers. Public backend,
state-model, circuit, protocol, logging-context, and optional-capability extension
interfaces are in scope. Generated package-extension modules and activation plumbing
are implementation details. Reproduction evidence is meaningful only with the software
environment, initial model, scheduling configuration, and Julia RNG state; the product
makes no built-in reproducibility promise. Transient console output does not belong in
the records.
