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
- `query_wait` and `querydelete_wait!` query first and only then wait.
- Because they query first, they provide the same high-level behavior on
  `Register` and `MessageBuffer` even though raw `onchange(...)` semantics
  differ between those stores.

## Event And Waiting Notes

- `onchange(mb, Tag)` currently behaves the same as `onchange(mb)`.
- Waiting helpers operate on `Register` and `MessageBuffer`, not on a single `RegRef`.
- Register waiting is pure future-edge waiting through `AsymmetricSemaphore`.
- Message buffers need extra bookkeeping because `AsymmetricSemaphore` is not a
  counting semaphore:
  - an `unlock` that happens with zero waiters is forgotten.
- `MessageBuffer.no_wait` stores one queued wakeup per arrival that happened
  before any waiter was registered.
- That queued wakeup is what makes later `onchange(mb)` calls wake immediately
  for already-buffered arrivals.
- When possible, prefer `query_wait` or `querydelete_wait!` over
  `onchange(...)` followed by a query:
  - that pattern is less timing-sensitive and has the same user-visible
    semantics everywhere.

## Review Checks

- Verify a proposed tag schema fits existing `Tag(...)` constructors before documenting it.
- Do not bless `tag!(register, ...)` or `tag!(messagebuffer, ...)`; both are rejected.
- Preserve query ordering semantics unless the change is intentional and broadly updated.
- Preserve the distinction between:
  - register `onchange`, which waits for future changes;
  - message-buffer `onchange`, which also consumes queued wakeups from earlier
    buffered arrivals.
- Prefer documenting `query_wait` and `querydelete_wait!` as the default waiting
  API when a concrete predicate is already known.
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
