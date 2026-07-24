# States Catalog

- **Context need:** Reference
- **Open when:** Choosing among the shipped symbolic noisy two-qubit state families.
- **Do not open when:** Adding a model, selecting a backend generally, or changing register storage.
- **Related specification IDs:** SYS-008, SUB-011, CMP-010
- **Review when:** StatesZoo exports, Genqo wrappers, parameters, or symbolic lowering changes.

## Model families

StatesZoo currently contains five symbolic two-qubit model types. Use the human API page
for constructors and formulas; this catalog records selection boundaries and maturity.

- `BarrettKokBellPair` represents a normalized noisy Barrett–Kok pair, while
  `BarrettKokBellPairW` preserves heralding probability in its trace.
- `DepolarizedBellPair` represents a depolarized Bell state and lowers to both
  QuantumOptics and Clifford representations.
- `StatesZoo.Genqo.GenqoMultiplexedCascadedBellPairW` wraps the heralded multiplexed
  cascaded-source model.
- `StatesZoo.Genqo.GenqoUnheraldedSPDCBellPairW` wraps the unheralded SPDC model.

Genqo.jl is a direct package dependency, not an optional Python integration. The two
wrappers are nested under `StatesZoo.Genqo`. In both current Genqo lowering paths the
public `Pᵈ` parameter is retained for compatibility but ignored because the called
Genqo density-matrix routines do not accept dark counts. Do not interpret a changed
`Pᵈ` value as simulated noise until that boundary changes.

`stateparameters` and `stateparametersrange` drive exploration and communicate useful
ranges. Those ranges are descriptive metadata; constructors do not consistently enforce
them. Validate physical domains at the calling boundary when invalid values would make
a study meaningless.

All five model types are covered by the API test’s generic trace check. Only add an
explicit `LinearAlgebra.tr` method when generic symbolic lowering is insufficient; the
Barrett–Kok path needs specialization, but explicit trace methods are not a general
StatesZoo requirement.

## Anchors

- **Source:** [`src/StatesZoo/StatesZoo.jl`](../../../src/StatesZoo/StatesZoo.jl), [`src/StatesZoo/barrett_kok.jl`](../../../src/StatesZoo/barrett_kok.jl), [`src/StatesZoo/depolarized.jl`](../../../src/StatesZoo/depolarized.jl), and [`src/StatesZoo/genqo.jl`](../../../src/StatesZoo/genqo.jl) — model definitions and lowering.
- **Docs:** [`docs/src/API_StatesZoo.md`](../../../docs/src/API_StatesZoo.md) and [`docs/src/state_visualization.md`](../../../docs/src/state_visualization.md) — constructors, formulas, and exploration.
- **Test:** [`test/general/stateszoo_api_tests.jl`](../../../test/general/stateszoo_api_tests.jl) — catalog surface and generic trace behavior.

## Unresolved questions

- Should parameter ranges become constructor validation contracts?
- How should Genqo wrappers expose that `Pᵈ` is currently ineffective?
