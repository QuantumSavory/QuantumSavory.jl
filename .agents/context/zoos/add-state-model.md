# Add a State Model

- **Context need:** Task playbook
- **Open when:** Implementing or revising a symbolic model in StatesZoo.
- **Do not open when:** Merely selecting an existing model or extending a general backend.
- **Related specification IDs:** SYS-008, SYS-009, SUB-011, CMP-010
- **Review when:** The StatesZoo model interface, explorer metadata, or supported representation boundary changes.

## Add the model

1. Define a focused symbolic type under `src/StatesZoo/`, normally as an
   `AbstractTwoQubitState` with `@withmetadata`. Document the parameters accepted by
   public constructors—the concrete struct-field layout remains internal—and state
   normalization or whether trace carries a heralding probability.
2. Add convenient constructors only where they preserve one unambiguous parameter
   convention. Implement `symbollabel` for compact displays.
3. Implement `stateparameters` and `stateparametersrange` for public models so callers
   can inspect constructor parameters and their expected values. Current ranges are
   descriptive and do not enforce validity.
4. Add `express_nolookup` only for representations whose semantics are actually
   implemented. Keep unsupported backends explicit. Use generic `tr` when symbolic
   lowering already makes it correct; specialize trace only when generic behavior is
   insufficient.
5. Include the file, document it in generated prose, and either export its public name
   or declare it `public`. If wrapping an external Julia library, declare its dependency
   status accurately. Genqo.jl is a direct dependency today; it is neither a weak
   dependency nor a Python bridge.
6. Extend `stateszoo_api_tests.jl` with construction, parameter metadata, trace, and
   supported lowering checks. Test only the documented representation subset; do not
   imply universal backend support. For weighted models, test both normalized
   conditional state and success-weight semantics where applicable.
7. Update the human StatesZoo API and any visualization examples. Keep formulas and
   full constructor catalogs there; this context leaf should retain only selection and
   maintenance boundaries.

When copying the Genqo wrappers, do not propagate their unresolved `Pᵈ` behavior:
the field is currently ignored by the external routines. Make every accepted public
constructor parameter affect the declared model, or remove it through the applicable
breaking-release process.

## Anchors

- **Source:** [`src/StatesZoo/StatesZoo.jl`](../../../src/StatesZoo/StatesZoo.jl), [`src/StatesZoo/depolarized.jl`](../../../src/StatesZoo/depolarized.jl), and [`src/StatesZoo/genqo.jl`](../../../src/StatesZoo/genqo.jl) — interface and contrasting implementations.
- **Docs:** [`docs/src/API_StatesZoo.md`](../../../docs/src/API_StatesZoo.md) and [`docs/src/state_visualization.md`](../../../docs/src/state_visualization.md) — public catalog and explorer expectations.
- **Test:** [`test/general/stateszoo_api_tests.jl`](../../../test/general/stateszoo_api_tests.jl) — focused model contract.

## Current boundary

`stateparametersrange` communicates useful values but does not establish constructor
validation or a package-wide numerical-accuracy promise. Each public model documents
the representations it actually supports.
