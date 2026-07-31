# Register Model

- **Context need:** Explanation
- **Open when:** Reasoning about slot ownership, subsystem grouping, initialization, or register/network structure.
- **Do not open when:** Looking up operation signatures, backend coverage, or metadata-query syntax.
- **Related specification IDs:** SYS-002, SYS-003, SYS-009, SYS-010, SYS-013, SUB-002, SUB-015, CMP-001, CMP-002
- **Review when:** Register storage, `StateRef`, initialization, factorization, inspection marking, display, or `RegisterNet` construction changes.

## Ownership and factorization

A `Register` owns a fixed vector of slots. Each occupied slot points through a
`StateRef` to a stored state and records which subsystem of that state the slot owns.
One state may therefore span several slots, including slots in different registers;
the bidirectional slot-to-state bookkeeping is the invariant that operations and
traceout must preserve. Empty slots have no state reference.

Each slot independently declares its quantum-state trait, preferred representation,
and optional background process. Register constructors either accept those parallel
vectors or fill them from trait defaults; do not infer one register-wide backend or
noise model.

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

Initialization, composition, and traceout perform multiple writes. A later validation
or backend exception can therefore follow an earlier mutation; the traceout tests
preserve one such partial-failure example. The package does not restore or promise a
consistent simulation after an exception. Abort that run instead of adding caller-side
recovery around partially mutated register state.

For inspection, qualified `QuantumSavory.stateof(slot)` returns its `StateRef` or
`nothing`, `QuantumSavory.quantumstate(stateref)` unwraps the native backend state, and
`QuantumSavory.slots(stateref)` reconstructs live `RegRef` back-references. These are
unexported and have no Julia `public` declaration. Maintainers classified all three as a
public-surface gap: human docs already teach `stateof`, while `quantumstate` and `slots`
still need generated prose as well as source marking under SYS-009. They are not
serialization APIs. Text display summarizes `Register`, `RegRef`, `StateRef`, and
`RegisterNet`; HTML display is specialized for `RegRef` and `StateRef`, with
backend-specific `stateshow` hooks and an escaped plain-text fallback. Rendering success
is covered by SYS-010, but exact display content is not stable data.

`RegisterNet` adds graph and simulation ownership around registers. Its constructor,
locality model, and known dynamic-insertion defects are canonicalized in the
[transport reference](../network/transport.md).

## Anchors

- **Source:** [`src/states_registers.jl`](../../../src/states_registers.jl), [`src/states_registers_networks_shows.jl`](../../../src/states_registers_networks_shows.jl), [`src/baseops/initialize.jl`](../../../src/baseops/initialize.jl), and [`src/networks.jl`](../../../src/networks.jl) — ownership, inspection, display, explicit tensor splitting, and network construction.
- **Docs:** [`docs/src/modeling_registers_and_time.md`](../../../docs/src/modeling_registers_and_time.md) and [`docs/src/register_interface.md`](../../../docs/src/register_interface.md) — human-facing register model.
- **Test:** [`test/general/register_interface_tests.jl`](../../../test/general/register_interface_tests.jl), [`test/general/show_html_tests.jl`](../../../test/general/show_html_tests.jl), [`test/general/show_gabs_tests.jl`](../../../test/general/show_gabs_tests.jl), and [`test/general/traceout_tests.jl`](../../../test/general/traceout_tests.jl) — ownership, inspection displays, and partial-failure evidence.

## Known gap

- `stateof`, `quantumstate`, and `slots` do not yet satisfy the complete documented plus
  exported/`public` convention.
