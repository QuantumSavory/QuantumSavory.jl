The documented extension contract is:

1. subtype `AbstractTwoQubitState`;
2. define `express_nolookup(x, ::QuantumOpticsRepr)`;
3. define `symbollabel(x)`;
4. define `tr(x)`;
5. define `state_family_schema(::Type{YourState})` with ordered
   `StateParameterSchema` entries and an explicit `NormalizedState` or
   `WeightedState` normalization style;
6. provide a constructor that accepts exactly the parameters in the family
   schema, in that order.

The explorer assumptions matter:

- it is meant for two-qubit state families;
- the explorer is built around a fixed two-qubit family interface;
- default values, slider sweep ranges, boundary inclusivity, and parameter
  order come from `state_family_schema`;
- `stateparameters` and `stateparametersrange` are derived compatibility APIs,
  not extension points for new families.

The main review checks are:

- keep `tr(state)` consistent with the expressed representation;
- keep weighted and normalized semantics explicit in docs and examples;
- keep constructor signatures synchronized with the ordered family schema;
- review parameter ranges for physical sanity, not just API shape.

Validation should stay anchored to the existing API coverage for `StatesZoo`
families and the state explorer workflow.
