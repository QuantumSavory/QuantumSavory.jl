# QuantumSavory V-Model

- **Profile status:** draft
- **Review state:** Maintainer interview incorporated; pending acceptance by
  maintainer-reviewed merge
- **Product boundary:** The living, repository-wide research and education simulator:
  package code, all built-in state, circuit, and protocol Zoos, built-in optional
  extensions, human and generated documentation, checked-in examples, and CI
  definitions. External dependencies and services are not part of the product, but
  their supported integrations are. `.agents/evals/` is unrelated and excluded.
- **Evidence snapshot:** Repository commit
  `ea409d15e138db957e646991478ec3c2d40257be`
- **Acceptance authority:** QuantumSavory maintainers through a reviewed merge
- **Last reviewed:** 2026-07-31

This is a living, aspirational product specification grounded in behavior and direction
recoverable from the current repository. Maintainer-validated intent and generated
human documentation define desired behavior; contradictory implementation is recorded
as a nonconformance. A planned record may describe an incomplete capability only when
that direction is recoverable from repository evidence or maintainer review.

## Left-side specification

1. [Stakeholder outcomes](01-stakeholder-outcomes.md)
2. [System requirements](02-system-requirements/index.md)
3. [Subsystem and interface contracts](03-subsystem-contracts/index.md)
4. [Component contracts](04-component-contracts/index.md)

## Right-side evidence mappings

- [Verification and acceptance actions](verification/index.md)

Each left-side record allocates an acceptance or verification action ID defined in the
right-side action shards.

## Baseline notes

- Semantic versioning governs compatibility for the public surface: an API is public
  only when it appears in generated prose documentation and is exported or declared
  `public`. No preceding deprecation release is required for a breaking change.
- Register trait defaults are the specific exception to SemVer protection. Omitting a
  slot representation selects `QuantumOpticsRepr`; specialized representations are
  never implicit slot defaults.
- Every public Zoo entry is supported, although each state entry may designate only a
  subset of numerical representations. Internal helpers are neither public nor
  SemVer-protected.
- Support otherwise applies only to documented compatible combinations of subsystem
  traits, symbolic objects, representations, operations, and background models.
- Preserved factorization means factorization explicitly present in a symbolic tensor
  expression; generic numerical separability detection is not promised.
- Exceptions terminate the affected run: no public operation promises rollback,
  failure atomicity, or a consistent simulation state after an exception.
- Sharing the software environment, initial state, scheduling configuration, and Julia
  RNG seed is necessary to assess reproducibility; the product makes no built-in
  repeatability promise.
- There is no formal performance, scale, universal numerical-accuracy, or service-level
  threshold. Severe performance regressions still require maintainer review.
- Supported external integrations must operate correctly when their dependencies and
  services are available; availability, latency, and long-term external behavior are
  outside the product contract.

## Acceptance and promotion gates

A maintainer-reviewed merge accepts changes to this specification. A verification
action may be marked passing only when its full criterion has focused automated
evidence, relevant declared CI-environment coverage, public documentation, a
user-oriented example where applicable, and explicit maintainer confirmation.

The current backend capability matrix, public declarations for documented unexported
APIs, automatic representation promotion, explicit twirling-based specialization, and
several Zoo contracts remain incomplete. Keep their actions planned or implemented
with explicit nonconformance until the corresponding evidence satisfies the full gate.
