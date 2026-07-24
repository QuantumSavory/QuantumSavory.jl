# Register Model

- **Context need:** Explanation
- **Open when:** Reasoning about slot ownership, subsystem grouping, initialization, or register/network structure.
- **Do not open when:** Looking up operation signatures, backend coverage, or metadata-query syntax.
- **Related specification IDs:** SYS-002, SYS-003, SUB-002, CMP-001, CMP-002
- **Review when:** Register storage, `StateRef`, initialization, factorization, or `RegisterNet` construction changes.

## Ownership and factorization

A `Register` owns a fixed vector of slots. Each occupied slot points through a
`StateRef` to a stored state and records which subsystem of that state the slot owns.
One state may therefore span several slots, including slots in different registers;
the bidirectional slot-to-state bookkeeping is the invariant that operations and
traceout must preserve. Empty slots have no state reference.

Initialization is intentionally explicit. A plain state is installed as one state
reference over the listed slots. Only symbolic `STensor` input is structurally split
into separate factor states. The implementation does not attempt general separability
detection for numeric backend objects. Code that relies on factorization must construct
the symbolic tensor accordingly or perform an explicit backend-aware decomposition.

When an operation spans independent state references, `apply!` composes them and keeps
the resulting joint representation in the register. In contrast, multi-state
`observable` evaluation composes a temporary value and leaves stored references
separate. This distinction affects later evolution cost and ownership shape even when
the immediate numerical answer is equivalent.

Mutation across several slots is not promised to be transactional. Initialization,
composition, and traceout perform multiple writes; a later validation or backend error
can follow an earlier successful mutation. The traceout tests deliberately preserve a
partial-failure example. Review callers that catch such errors as potentially needing
cleanup rather than assuming rollback.

`RegisterNet` associates a graph, registers, and one simulation. Its constructor
currently constructs but does not throw the graph/register size error, and
`add_register!` does not completely update all network structures. Treat dynamic
register insertion and mismatched construction as known defects, not supported
invariants.

## Anchors

- **Source:** [`src/states_registers.jl`](../../../src/states_registers.jl), [`src/baseops/initialize.jl`](../../../src/baseops/initialize.jl), and [`src/networks.jl`](../../../src/networks.jl) — ownership, explicit tensor splitting, and network construction.
- **Docs:** [`docs/src/modeling_registers_and_time.md`](../../../docs/src/modeling_registers_and_time.md) and [`docs/src/register_interface.md`](../../../docs/src/register_interface.md) — human-facing register model.
- **Test:** [`test/general/register_interface_tests.jl`](../../../test/general/register_interface_tests.jl) and [`test/general/traceout_tests.jl`](../../../test/general/traceout_tests.jl) — ownership behavior and non-atomic failure evidence.

## Unresolved questions

- Should multi-slot mutations eventually guarantee rollback, or should partial mutation become an explicit public contract?
- What final invariant and return value should `add_register!` provide?
