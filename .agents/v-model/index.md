# QuantumSavory V-Model

- **Profile status:** draft
- **Product boundary:** The current development package pinned at commit
  `d7523d33e10bbb199e26a7dea074a54f34646d24`, including its built-in state,
  circuit, and protocol catalogs and its optional Julia extensions. Third-party
  dependencies, hosted demos or services, and `.agents/evals/` are outside this
  product boundary.
- **Acceptance authority:** QuantumSavory maintainers (developer confirmation pending)
- **Last reviewed:** 2026-07-24

This profile is a repository-specific specification and evidence map. It is not a
claim of compliance with NASA, FDA, ECSS, or V-Modell XT.

The normative statements below are a draft recovered from public documentation,
implementation behavior, and tests at the pinned development commit. Those sources
show current behavior but do not establish intended behavior without maintainer
confirmation.

## Left-side specification

1. [Stakeholder outcomes](01-stakeholder-outcomes.md)
2. [System requirements](02-system-requirements.md)
3. [Subsystem and interface contracts](03-subsystem-contracts/index.md)
4. [Component contracts](04-component-contracts/index.md)

## Right-side evidence mappings

- [Verification and acceptance actions](verification/index.md)

Each left-side record allocates an acceptance or verification action ID defined in the
right-side action shards.

## Baseline notes

- Whether this profile should baseline the pinned development state or a released
  version remains unresolved.
- Support applies only to documented compatible combinations of subsystem traits,
  symbolic objects, numerical representations, operations, and background models.
- Preserved factorization means factorization explicitly present in a symbolic tensor
  expression; this draft does not claim generic numerical separability detection.
- Unsupported backend combinations do not yet share one standard error type or
  diagnostic.
- Failed multi-slot operations do not have a general atomicity or rollback guarantee.
- The support maturity and cross-release stability of individual Zoo entries remain
  unresolved.
- No performance budget or scientific-accuracy budget has been confirmed.
- Context links are supplementary forward references for the coordinated context
  migration. Normative meaning remains entirely in this V-model.
- Unresolved intent does not form part of a baseline.

## Gates before baselining

The acceptance authority must confirm the release/development boundary, enumerate the
backend-by-capability combinations designated supported, identify the supported versus
experimental entries in each Zoo, enumerate the supported external extension seams and
optional entry points, and choose the public stability boundary. Until those
inventories exist, a record using “supported” or “designated supported” is a candidate
requirement: its action may be implemented, but it cannot be marked passing.
