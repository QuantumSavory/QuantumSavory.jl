# StatesZoo for Developers

Open this file when:

- adding or reviewing a `StatesZoo` state family;
- changing state explorer behavior;
- debugging `StatesZoo` expression paths or parameter exposure.

Do not use this file for simple model selection.
Use `.agents/zoos/states-zoo-user.md` for that.

## Extension Contract

- Subtype `AbstractTwoQubitState`.
- Define:
  - `express_nolookup(x, ::QuantumOpticsRepr)`
  - `symbollabel(x)`
  - `tr(x)`
  - `stateparameters(::Type{YourState})`
  - `stateparametersrange(::Type{YourState})`
- Provide a constructor that accepts exactly the parameters returned by `stateparameters`, in that order.

## Explorer Assumptions

- The explorer is meant for two-qubit state families.
- `src/StatesZoo/state_explorer.jl` declares the interface.
- The main UI implementation lives in `ext/QuantumSavoryMakie/state_explorer.jl`.
- Explorer defaults and sweep ranges come directly from `stateparametersrange`.

## Review Checks

- Verify `tr(state)` matches the expressed representation.
- Keep weighted and normalized semantics explicit in docstrings and examples.
- Keep constructor signatures synchronized with `stateparameters`.
- Treat `Genqo` breakage as a possible dependency problem before assuming a Julia logic bug.
- Review parameter ranges for physical sanity, not just API shape.

## Source Files To Read

- `src/StatesZoo/StatesZoo.jl`
- `src/StatesZoo/barrett_kok.jl`
- `src/StatesZoo/genqo.jl`
- `src/StatesZoo/state_explorer.jl`
- `ext/QuantumSavoryMakie/state_explorer.jl`

## Tests And Examples To Anchor Behavior

- `test/general/stateszoo_api_tests.jl`
- `test/examples/state_explorer_tests.jl`
- `examples/state_explorer/README.md`
- `examples/state_explorer/state_explorer.jl`

## Public Docs And Paper To Cross-Check

- `docs/src/API_StatesZoo.md`
- `docs/src/zoos_as_building_blocks.md`
- `docs/src/tutorial/state_explorer.md`
- `../writeup/zoos.tex`
