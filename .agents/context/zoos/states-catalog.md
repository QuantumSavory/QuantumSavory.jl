# States Catalog

- **Context need:** Reference
- **Open when:** Choosing among the shipped symbolic noisy two-qubit state families.
- **Do not open when:** Adding a model, selecting a backend generally, or changing register storage.
- **Review when:** StatesZoo exports, Genqo wrappers, parameters, or symbolic lowering changes.

## Model families

StatesZoo currently contains five symbolic two-qubit model types. Entries that satisfy
the public convention are supported; use the human API page for constructor parameters
and formulas.

- `BarrettKokBellPair` represents a normalized noisy Barrett–Kok pair, while
  `BarrettKokBellPairW` preserves heralding probability in its trace.
- `DepolarizedBellPair` represents a depolarized Bell state and lowers to both
  QuantumOptics and Clifford representations.
- `StatesZoo.Genqo.GenqoMultiplexedCascadedBellPairW` wraps the heralded multiplexed
  cascaded-source model.
- `StatesZoo.Genqo.GenqoUnheraldedSPDCBellPairW` wraps the unheralded SPDC model.

Genqo.jl is a direct package dependency, not an optional Python integration. The two
wrappers are nested under `StatesZoo.Genqo`. They have docstrings and a dedicated
generated-docs section, but are neither exported nor declared `public`; that marking gap
keeps source and the public catalog out of alignment. In both lowering paths
the constructor parameter `Pᵈ` is retained for compatibility but ignored because the
called Genqo density-matrix routines do not accept dark counts. Do not interpret a
changed `Pᵈ` value as simulated noise until that boundary changes.

`stateparameters` and `stateparametersrange` drive exploration and communicate useful
ranges. Those ranges are descriptive metadata; constructors do not consistently enforce
them. They are the current expected-value introspection surface for constructor
parameters; concrete state-object field layout is not the public contract.

All five model types are covered by the API test’s default-QuantumOptics trace check,
which does not establish every representation. Support is intentionally per-model and
per-representation rather than universal.
The separate Clifford check for `DepolarizedBellPair` lives in
`test/test_stateszoo_depolarized.jl`, which the current `_tests.jl` filename filter does
not discover. Only add an explicit `LinearAlgebra.tr` method when generic symbolic
lowering is insufficient; the Barrett–Kok path needs specialization, but explicit
trace methods are not a general StatesZoo requirement.

## Anchors

- **Source:** [`src/StatesZoo/StatesZoo.jl`](../../../src/StatesZoo/StatesZoo.jl), [`src/StatesZoo/barrett_kok.jl`](../../../src/StatesZoo/barrett_kok.jl), [`src/StatesZoo/depolarized.jl`](../../../src/StatesZoo/depolarized.jl), and [`src/StatesZoo/genqo.jl`](../../../src/StatesZoo/genqo.jl) — model definitions and lowering.
- **Docs:** [`docs/src/API_StatesZoo.md`](../../../docs/src/API_StatesZoo.md) and [`docs/src/state_visualization.md`](../../../docs/src/state_visualization.md) — constructors, formulas, and exploration.
- **Test:** [`test/general/stateszoo_api_tests.jl`](../../../test/general/stateszoo_api_tests.jl) and the currently orphaned [`test/test_stateszoo_depolarized.jl`](../../../test/test_stateszoo_depolarized.jl) — catalog surface and backend-specific evidence.

## Known gaps

- The two Genqo model types lack `export` or `public` marking.
- Both Genqo lowerings ignore their accepted `Pᵈ` constructor parameter.
- `BarrettKokBellPair` accepts and documents `m`, but its parameter/range
  introspection omits it; the weighted model's convenience constructors also lack
  constructor-parameter prose.
- The Clifford depolarized-state test is not discovered by the test runner.
