The main limitations are the ones that come from the chosen modeling layer and
backend, not from one single global “trustworthiness” switch.

The biggest ones to keep in mind are:

- backend scope still matters;
- symbolic descriptions do not erase backend limits;
- and some networking behaviors are modeled at higher layers than others.

Concretely:

- `CliffordRepr()` is fast because it assumes stabilizer-friendly dynamics and
  Pauli-like noise;
- `GabsRepr(...)` is efficient because it assumes Gaussian continuous-variable
  structure;
- `QuantumOpticsRepr()` is more general, but the price is much worse scaling.

So if your physics leaves the assumptions of a restricted backend, you should
not trust that backend just because the symbolic API still accepts your model.

There are also some important modeling boundaries in the networking layer:

- classical forwarding exists, but automatic multihop quantum routing does not;
- locality is modeled through graphs, channels, and delays, but not enforced at
  the Julia language level;
- weighted `StatesZoo` families are not the same thing as normalized states.

The docs also note some current scope limits:

- tensor-network and similar reduced-complexity backends fit the architecture,
  but are not yet first-class built-in options;
- some how-to pages are still marked unfinished, so the clearest source of
  truth is often the combination of the conceptual docs, API pages, and bundled
  examples.

The safest workflow is:

1. choose the cheapest backend that preserves the effect you care about;
2. validate that approximation on smaller instances with a more general backend
   when the result matters;
3. stay explicit about what is being approximated and what is only being
   modeled at the control layer.

