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
  - `state_family_schema(::Type{YourState})`
- Provide a constructor that accepts exactly the ordered parameters in
  `StateFamilySchema.parameters`.
- Mark the family `NormalizedState` or `WeightedState`; never infer this from
  its type name.

## Explorer Assumptions

- The explorer is meant for two-qubit state families.
- `src/StatesZoo/state_explorer.jl` declares the interface.
- The main UI implementation lives in `ext/QuantumSavoryMakie/state_explorer.jl`.
- Explorer defaults and sweep ranges come from `StateFamilySchema.parameters`
  through the compatibility `stateparameters` and `stateparametersrange` APIs.

## Metadata And Normalization Invariants

- `state_family_schemas()` is an explicit built-in catalog; loading unrelated
  packages must not change it.
- Parameter names, exact boundaries, boundary inclusivity, recommendations, and
  docs have one source of truth in `StateParameterSchema`.
- `value in parameter_schema` is the validation boundary for configuration
  tooling. Open endpoints represent singular or zero-weight states, not merely
  UI hints.
- The REST example has an explicit, closed query-parameter allowlist for every
  route and rejects undeclared parameters with HTTP 400.
- `stateparameters` and `stateparametersrange` are derived compatibility APIs;
  do not add parallel family-specific methods for built-ins.
- `state_weight` returns the finite absolute trace.
- `normalized_state_and_weight` returns normalized families unchanged and
  divides only declared weighted families, returning the original weight.
- Zero-weight states cannot be normalized. Never silently discard a weight in
  register initialization or serialization.

## Review Checks

- Verify `tr(state)` matches the expressed representation.
- Keep weighted and normalized semantics explicit in docstrings and examples.
- Keep constructor signatures synchronized with the state-family schema.
- Expose only parameters that affect the selected backend; never retain a
  wrapper field solely for compatibility when the backend ignores it.
- Treat `Genqo` breakage as a possible dependency problem before assuming a Julia logic bug.
- Review parameter ranges for physical sanity, not just API shape.
- For every built-in parameter, test both endpoints against finite,
  positive-trace state expression and keep the inclusivity flags synchronized
  with that result.

## Source Files To Read

- `src/StatesZoo/StatesZoo.jl`
- `src/StatesZoo/barrett_kok.jl`
- `src/StatesZoo/genqo.jl`
- `src/StatesZoo/metadata.jl`
- `src/StatesZoo/state_explorer.jl`
- `ext/QuantumSavoryMakie/state_explorer.jl`

## Tests And Examples To Anchor Behavior

- `test/general/stateszoo_api_tests.jl`
- `test/examples/state_explorer_tests.jl`
- `test/examples/states_rest_server_contract_tests.jl`
- `examples/state_explorer/README.md`
- `examples/state_explorer/state_explorer.jl`

## Public Docs And Paper To Cross-Check

- `docs/src/API_StatesZoo.md`
- `docs/src/zoos_as_building_blocks.md`
- `docs/src/tutorial/state_explorer.md`
