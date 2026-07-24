# Register Operations

- **Context need:** Reference
- **Open when:** Checking current register operation ordering, composition, tracing, or backend-dispatch boundaries.
- **Do not open when:** Learning the ownership model, adding a backend, or working only on tags and messages.
- **Related specification IDs:** SYS-001, SYS-002, SYS-003, SUB-001, SUB-003, CMP-002, CMP-003, CMP-004
- **Review when:** `initialize!`, `apply!`, `observable`, `traceout!`, `uptotime!`, or symbolic lowering changes.

## Operation contract

Register operations take slot references, validate ownership, bring relevant state
forward in simulation time where required, and dispatch representation-specific work.
The symbolic frontend supplies backend-neutral states, operations, and observables;
backend methods lower or execute them. Consult the human API pages for signatures
rather than duplicating their catalog here.

`initialize!` installs a plain state as one shared state reference. Its specialized
symbolic `STensor` method installs factors independently; arbitrary numeric tensor
objects are not analyzed for separability. `apply!` first advances participating
states, composes distinct references when needed, applies the operation, and persists
the composed state. `observable` also advances state, but composes independent
references only in a temporary value, preserving stored factorization.

`traceout!` groups slots that share a state reference so the backend receives the
discarded subsystem positions together. For `MCKet`, traceout is trajectory semantics:
the discarded subsystem is sampled in its canonical basis and the retained conditional
state remains an `MCKet`; it is not converted into a mixed density operator. Multi-slot
mutation is not atomic. An error after an earlier group succeeds may leave that group
removed.

`uptotime!` evolves each distinct state through its background model toward the
requested time. Current ordering can evolve a stored backend state before the
no-rewind check raises, so catching a rewind error does not establish that nothing
changed. Chronological access-time and background behavior belongs with the time/noise
reference.

Generic implementations should be preferred when representation traits make them
correct. Add explicit methods such as `tr` only when generic behavior is insufficient;
the StatesZoo suite demonstrates that most model traces work generically while the
Barrett–Kok model needs specialization.

## Anchors

- **Source:** [`src/baseops/apply.jl`](../../../src/baseops/apply.jl), [`src/baseops/observable.jl`](../../../src/baseops/observable.jl), [`src/baseops/traceout.jl`](../../../src/baseops/traceout.jl), and [`src/baseops/uptotime.jl`](../../../src/baseops/uptotime.jl) — operation sequencing and grouping.
- **Docs:** [`docs/src/register_interface.md`](../../../docs/src/register_interface.md) and [`docs/src/symbolic_frontend.md`](../../../docs/src/symbolic_frontend.md) — public operations and symbolic boundary.
- **Test:** [`test/general/apply_tests.jl`](../../../test/general/apply_tests.jl), [`test/general/observable_tests.jl`](../../../test/general/observable_tests.jl), and [`test/general/traceout_tests.jl`](../../../test/general/traceout_tests.jl) — executable behavior.

## Unresolved questions

- Should rewind validation happen before any backend evolution?
- Which multi-operation failure cases should acquire explicit atomicity guarantees?
