# QuantumSavory.jl Agent Guide

This file is the entry point for work inside `QuantumSavory.jl`.
Do not load the whole `.agents/` tree by default.
Open only the topic files that match the task.

## First Pass

- Decide whether the task is primarily user-facing, contributor-facing, or review-heavy.
- Start from public docs and examples for user behavior, then confirm in source if anything looks ambiguous.
- Start from source and tests for internal changes, review, or bug hunting.
- Cross-check public claims against the implementation before editing docs. A few docs intentionally simplify internals, and a few details lag the code.

## Topic Router

- Register API, factorization, time semantics, backend hooks:
  - user: `.agents/registers/register-interface-user.md`
  - dev/review: `.agents/registers/register-internals-and-backend-hooks.md`
- Tags, queries, metadata plane, waiting on tags/messages:
  - user: `.agents/metadata/tags-queries-user.md`
  - dev/review: `.agents/metadata/tags-queries-dev.md`
- Classical messaging, message buffers, quantum transport:
  - user: `.agents/channels/classical-and-quantum-channels-user.md`
  - dev/review: `.agents/channels/classical-and-quantum-channels-dev.md`
- `StatesZoo`:
  - user: `.agents/zoos/states-zoo-user.md`
  - dev/review: `.agents/zoos/states-zoo-dev.md`
- `CircuitZoo`:
  - user: `.agents/zoos/circuit-zoo-user.md`
  - dev/review: `.agents/zoos/circuit-zoo-dev.md`
- `ProtocolZoo`:
  - user: `.agents/zoos/protocol-zoo-user.md`
  - dev/review: `.agents/zoos/protocol-zoo-dev.md`

## Shared Source Map

- Public docs live in `docs/src/`.
- Core implementation lives in `src/`.
- Example scripts live in `examples/`.
- Regression and behavior anchors live in `test/general/` and `test/examples/`.
- The paper and writeup sources most relevant to this package live in:
  - `../writeup/quantumsavory.tex`
  - `../writeup/Overview.tex`
  - `../writeup/modeling.tex`
  - `../writeup/discrete_event.tex`
  - `../writeup/Tags.tex`
  - `../writeup/zoos.tex`
  - `../writeup/qtcp.tex`

## Repo Workflow

- Work from the package root: `QuantumSavory.jl/`.
- Prefer targeted tests first, then broader runs if behavior changed across multiple subsystems.
- When you change public APIs, examples, or user-visible behavior, update the matching `docs/src/` page and the matching `.agents/` topic file.
- When you change docstrings or documentation structure, build docs with `julia --project=docs docs/make.jl`.
- Many examples are mirrored by tests in `test/examples/`; use those tests as the safer validation path when possible.

## Review Hotspots

- Register changes:
  - factorization and `StateRef` backreferences
  - time monotonicity and `uptotime!`
  - register-to-state lowering behavior
- Metadata changes:
  - query ordering
  - tag schema compatibility
  - `locked=` and `assigned=` filtering
- Protocol changes:
  - lock release on all paths
  - tracker and cutoff interactions
  - nonzero `classical_delay` assumptions
  - tag/message field ordering
- Channel changes:
  - no lost wakeups in `MessageBuffer`
  - direct-edge versus forwarded classical traffic
  - empty destination slot requirement for `QuantumChannel`

## Documentation Boundary

- User files under `.agents/` should stay on public APIs, examples, and mental models.
- Dev files under `.agents/` should cover internals, invariants, tests, and review checks.
- If a detail is only useful for contributors or reviewers, keep it out of the user files.
