# Time and Noise

- **Context need:** Reference
- **Open when:** Checking access times, chronological evolution, background dispatch, or non-instant operation behavior.
- **Do not open when:** Working only on tags, transport routing, or zoo inventory.
- **Related specification IDs:** SYS-003, SYS-007, SUB-003, SUB-010, CMP-004, CMP-009
- **Review when:** `uptotime!`, background models, non-instant operations, or backend evolution methods change.

## Chronological evolution contract

Each register slot tracks an access time, while state references may span several
slots. Before an operation reads or mutates state, `uptotime!` groups the affected
state, evolves it through its configured backgrounds to the target simulation time,
and updates access-time bookkeeping. Callers must not move a slot backward in time.

The current implementation checks rewind conditions after backend evolution within the
grouped path. A request that throws for an earlier target can therefore follow an
in-place backend mutation. Treat rewind failure as potentially state-changing until
ordering is corrected and regression-tested.

Background support is backend-specific. QuantumOptics handles broad ket/operator
evolution and Monte Carlo trajectories. Clifford implements only its compatible T2
and depolarization cases. Gabs has a smaller Gaussian surface. `PauliNoise` helper
definitions currently disagree with their call sites, so neither source presence nor a
generic noise type proves that a backend/noise pair works. Consult focused tests for
each combination.

Non-instant operations are simulation processes: they acquire or coordinate resources,
advance time through yielded events, and expose the state to background evolution over
the interval. Review both the mathematical lowering and the event schedule. A correct
instantaneous backend method is not sufficient evidence that interruption, occupancy,
or cleanup behavior is correct.

The current trait implementation and backend guide map both `Qubit` and `Qumode` to
`QuantumOpticsRepr`, while the 0.7.0 `CHANGELOG.md` entry says Gabs became the default
for qumodes. Until that conflict is resolved, code requiring a particular physical
approximation should select its representation explicitly.

## Anchors

- **Source:** [`src/baseops/uptotime.jl`](../../../src/baseops/uptotime.jl), [`src/backgrounds.jl`](../../../src/backgrounds.jl), [`src/noninstant.jl`](../../../src/noninstant.jl), and [`src/backends/`](../../../src/backends/) — time ordering and backend evolution.
- **Docs:** [`docs/src/backgrounds.md`](../../../docs/src/backgrounds.md), [`docs/src/modeling_registers_and_time.md`](../../../docs/src/modeling_registers_and_time.md), [`docs/src/tutorial/noninstantgate.md`](../../../docs/src/tutorial/noninstantgate.md), and [`CHANGELOG.md`](../../../CHANGELOG.md) — background, non-instant, and conflicting default claims.
- **Test:** [`test/general/noninstant_and_backgrounds_qubit_tests.jl`](../../../test/general/noninstant_and_backgrounds_qubit_tests.jl), [`test/general/noninstant_and_backgrounds_clifford_tests.jl`](../../../test/general/noninstant_and_backgrounds_clifford_tests.jl), and [`test/general/noninstant_and_backgrounds_qumode_tests.jl`](../../../test/general/noninstant_and_backgrounds_qumode_tests.jl) — backend-specific evolution.

## Unresolved questions

- Must rewind errors be guaranteed side-effect free?
- Which background/backend combinations are intended requirements rather than opportunistic support?
