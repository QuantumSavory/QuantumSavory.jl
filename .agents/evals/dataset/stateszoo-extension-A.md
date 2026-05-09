The documented extension contract is:

1. subtype `AbstractTwoQubitState`;
2. define `express_nolookup(x, ::QuantumOpticsRepr)`;
3. define `symbollabel(x)`;
4. define `tr(x)`;
5. define `stateparameters(::Type{YourState})`;
6. define `stateparametersrange(::Type{YourState})`;
7. provide a constructor that accepts exactly the parameters returned by
   `stateparameters`, in that order.

The explorer assumptions matter:

- it is meant for two-qubit state families;
- the explorer is built around a fixed two-qubit family interface;
- default values and slider sweep ranges come directly from
  `stateparametersrange`.

The main review checks are:

- keep `tr(state)` consistent with the expressed representation;
- keep weighted and normalized semantics explicit in docs and examples;
- keep constructor signatures synchronized with `stateparameters`;
- review parameter ranges for physical sanity, not just API shape.

Validation should stay anchored to the existing API coverage for `StatesZoo`
families and the state explorer workflow.
