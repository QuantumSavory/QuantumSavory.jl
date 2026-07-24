# Time and Noise

- **Context need:** Reference
- **Open when:** Checking access times, chronological evolution, background dispatch, or non-instant operation behavior.
- **Do not open when:** Working only on tags, transport routing, or zoo inventory.
- **Related specification IDs:** SYS-003, SYS-007, SUB-003, SUB-010, CMP-004, CMP-009
- **Review when:** `uptotime!`, background models, non-instant operations, or backend evolution methods change.

## Chronological evolution contract

Each register slot tracks an access time, while state references may span several
slots. Advancement is demand-driven but not implicit in every operation:

- `apply!` targets the maximum selected access time unless a non-earlier `time` is
  supplied, then calls `uptotime!`;
- `observable` and `project_traceout!` call `uptotime!` only when `time` is supplied;
- plain `traceout!` performs no time advancement; and
- `initialize!` changes access time only when given `time`.

Explicit `uptotime!` groups affected state, applies configured backgrounds, and updates
slot access times. Callers must not move a slot backward in time.

The current implementation checks rewind conditions after backend evolution within the
grouped path. A request that throws for an earlier target can therefore follow an
in-place backend mutation. Treat rewind failure as potentially state-changing until
ordering is corrected and regression-tested.

Background and default-representation support is backend-specific. Use the
[backend support matrix](backend-support.md) as the canonical account of implemented
combinations, the `PauliNoise` dispatch defect, and the unresolved `Qumode` default.

`NonInstantGate` and `ConstantHamiltonianEvolution` are synchronous `apply!` methods,
not ConcurrentSim processes: they do not yield, acquire scheduler resources, or advance
the scheduler clock. `NonInstantGate` applies its gate and evolves selected state to a
later access time. `ConstantHamiltonianEvolution` invokes the backend's non-instant
evolution and overwrites selected access times at the end of the duration. The third
example in `docs/src/tutorial/noninstantgate.md` currently constructs `gate =
NonInstantGate(...)` but calls `apply!(..., CNOT)`, so it does not demonstrate the
object it describes.

## Anchors

- **Source:** [`src/baseops/uptotime.jl`](../../../src/baseops/uptotime.jl), [`src/backgrounds.jl`](../../../src/backgrounds.jl), [`src/noninstant.jl`](../../../src/noninstant.jl), and [`src/backends/`](../../../src/backends/) — time ordering and backend evolution.
- **Docs:** [`docs/src/backgrounds.md`](../../../docs/src/backgrounds.md), [`docs/src/modeling_registers_and_time.md`](../../../docs/src/modeling_registers_and_time.md), [`docs/src/tutorial/noninstantgate.md`](../../../docs/src/tutorial/noninstantgate.md), and [`CHANGELOG.md`](../../../CHANGELOG.md) — background, non-instant, and conflicting default claims.
- **Test:** [`test/general/noninstant_and_backgrounds_qubit_tests.jl`](../../../test/general/noninstant_and_backgrounds_qubit_tests.jl), [`test/general/noninstant_and_backgrounds_clifford_tests.jl`](../../../test/general/noninstant_and_backgrounds_clifford_tests.jl), and [`test/general/noninstant_and_backgrounds_qumode_tests.jl`](../../../test/general/noninstant_and_backgrounds_qumode_tests.jl) — backend-specific evolution.

## Unresolved questions

- Must rewind errors be guaranteed side-effect free?
- Which background/backend combinations are intended requirements rather than opportunistic support?
