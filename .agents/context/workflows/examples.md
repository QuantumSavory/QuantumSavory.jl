# Examples

- **Context need:** Task playbook
- **Open when:** Adding, changing, or validating a runnable example or tutorial script.
- **Do not open when:** Work is confined to unit tests, documentation prose, or benchmark definitions.
- **Related specification IDs:** None — repository-only workflow
- **Review when:** The examples project, wrapper inventory, example shard routing, or docs/example coupling changes.

## Change and validate an example

1. Work in the top-level `examples/` project, which has its own dependencies and a
   source mapping back to the repository. Do not use the nonexistent
   `test/projects/examples` path listed in the root workspace; `test/runtests.jl`
   correctly routes names beginning `examples` to the top-level project.
2. Keep setup code reusable within an example family and keep the runnable script
   deterministic enough for automated inclusion. Avoid interactive-only behavior in
   the tested path; plotting or server startup should have a bounded test mode.
3. Add or update the corresponding `_tests.jl` wrapper under `test/examples/`.
   There are currently 35 discoverable wrappers. Match the runner’s suffix and naming
   convention so a focused prefix and the examples shard find it.
4. Decide whether the wrapper is a smoke check or a behavioral check. Most current
   wrappers primarily include a script and establish that it completes without
   throwing. Meaningful assertions are concentrated in the assisted continuous-variable
   teleportation, full MBQC purification, custom MySwapper, and QTCP examples. Add
   assertions for stable results when the example is meant to verify more than
   executability.
5. Run the focused wrapper, then the examples shard when shared setup, dependencies, or
   a commonly imported subsystem changed. Run plotting separately for examples whose
   automated path produces figures.
6. Update the matching human tutorial or how-to if users encounter the example through
   docs. Remember that a script can be tested without its documentation page appearing
   in `docs/make.jl` navigation.

Do not report “example behavior verified” from inclusion-only wrappers; report the
actual asserted properties or label the result a smoke test.

## Anchors

- **Source:** [`examples/`](../../../examples/) and [`examples/Project.toml`](../../../examples/Project.toml) — runnable scripts and their environment.
- **Docs:** [`docs/src/howto.md`](../../../docs/src/howto.md) and [`docs/src/tutorial.md`](../../../docs/src/tutorial.md) — human entry points.
- **Test:** [`test/examples/`](../../../test/examples/) and [`test/runtests.jl`](../../../test/runtests.jl) — 35 wrappers and project routing.
- **CI:** [`.buildkite/pipeline.yml`](../../../.buildkite/pipeline.yml) — separate example and plotting shards.

## Unresolved questions

- Which inclusion-only wrappers should gain stable behavioral assertions?
- Should every published example have a one-to-one wrapper and navigation entry?
