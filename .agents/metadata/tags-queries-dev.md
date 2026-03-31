# Tag/Query Internals, Extension Points, and Review Checks

Open this file when:

- changing tag schemas, query behavior, or wait helpers;
- reviewing metadata-plane code;
- debugging ordering, duplicate tags, or query matching behavior;
- extending protocol message contracts.

Do not use this file for basic public API guidance.
Use `.agents/metadata/tags-queries-user.md` for that.

## Internal Model

- `Tag` is a `@sum_type` in `src/tags.jl` with a fixed set of supported payload shapes.
- The current implementation is narrower than some high-level prose suggests:
  - `TagElementTypes = Union{Symbol, Int, DataType}`
  - extra explicit variants exist for some `Float64` cases
  - there is no generic string payload path
- Register tags are stored globally per register:
  - ordered ids in `reg.guids`
  - payloads in `reg.tag_info[id] = (; tag, slot, time)`
- Message buffers store `(; src, tag)` entries in arrival order.

## Query Semantics That Matter In Review

- Register queries default to FILO ordering.
- Tests cover both `filo=true` and `filo=false`; do not change ordering lightly.
- Duplicate tags are allowed.
- `queryall` is intentionally register-only.
- Message-buffer `querydelete!` removes by vector depth, not by tag id.
- `query_wait` and `querydelete_wait!` are wrappers around `query` plus `onchange`.

## Event And Waiting Notes

- `onchange(mb, Tag)` currently behaves the same as `onchange(mb)`.
- Waiting helpers operate on `Register` and `MessageBuffer`, not on a single `RegRef`.
- Message buffers are not purely edge-triggered:
  - `tag_waiter` wakes tasks that are already blocked.
  - `no_wait` stores one pending wakeup per arrival that happened with no active waiter.
- Keep that queued-wakeup behavior when refactoring waits:
  - protocol code can inspect/query the buffer and only later call `onchange`
  - tests also rely on later waits waking immediately for already-buffered arrivals
  - removing `no_wait` turns buffered arrivals into invisible work for later waiters

## Review Checks

- Verify a proposed tag schema fits existing `Tag(...)` constructors before documenting it.
- Do not bless `tag!(register, ...)` or `tag!(messagebuffer, ...)`; both are rejected.
- Preserve query ordering semantics unless the change is intentional and broadly updated.
- When protocol code queries resources, check whether it should also constrain `locked=` or `assigned=`.
- Keep user docs honest about the current implementation. The current code does not support arbitrarily rich tag payloads.

## Source Files To Read

- `src/tags.jl`
- `src/queries.jl`
- `src/querywait.jl`
- `src/messagebuffer.jl`

## Tests To Anchor Behavior

- `test/general/tags_and_queries_tests.jl`
- `test/general/querywait_tests.jl`
- `test/general/messagebuffer_tests.jl`

## Public Docs And Paper To Cross-Check

- `docs/src/tag_query.md`
- `docs/src/metadata_plane.md`
- `docs/src/discreteeventsimulator.md`
- `docs/src/classical_messaging.md`
