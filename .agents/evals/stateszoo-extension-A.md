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
- the explorer interface is declared in `src/StatesZoo/state_explorer.jl`;
- the Makie UI lives in `ext/QuantumSavoryMakie/state_explorer.jl`;
- default values and slider sweep ranges come directly from
  `stateparametersrange`.

The review checks called out in `.agents` are:

- keep `tr(state)` consistent with the expressed representation;
- keep weighted and normalized semantics explicit in docs and examples;
- keep constructor signatures synchronized with `stateparameters`;
- review parameter ranges for physical sanity, not just API shape.

Tests and examples worth using as anchors:

- `test/general/stateszoo_api_tests.jl`
- `test/examples/state_explorer_tests.jl`
- `examples/state_explorer/README.md`
- `examples/state_explorer/state_explorer.jl`

