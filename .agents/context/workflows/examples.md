# Examples

- **Context need:** Task playbook
- **Open when:** Adding, changing, or validating a runnable example or tutorial script.
- **Do not open when:** Work is confined to unit tests, documentation prose, or benchmark definitions.
- **Review when:** The examples project, wrapper inventory, example shard routing, or docs/example coupling changes.

## Change and validate an example

1. Work in the top-level `examples/` project, which has its own dependencies and a
   source mapping back to the repository. Do not use the nonexistent
   `test/projects/examples` path listed in the root workspace; `test/runtests.jl`
   correctly routes names beginning `examples` to the top-level project.
2. Keep setup code reusable within an example family. When repeatability matters,
   record the software environment, initial state, scheduling configuration, and Julia
   RNG seed; QuantumSavory makes no built-in reproducibility promise. Avoid
   interactive-only behavior in the tested path; plotting or server startup should have
   a bounded test mode.
3. Add or update the corresponding `_tests.jl` wrapper under `test/examples/`.
   Buildkite passes the `example`
   selector, which selects the `examples/*_tests.jl` names. Match the runner’s suffix
   and naming convention so both focused and CI runs find it.
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

The MBQC family shares `examples/purificationMBQC/setup.jl` between its Werner
sweep and GLMakie hardware-source dashboard. Its `interactive_setup.jl` verifies
Bell-diagonal source mixtures before Clifford sampling. The interactive wrapper
checks source frames, ideal outputs, noisy trajectories, the 100-result window,
and slider snapshots/pause behavior; it requires a display or Xvfb. See the
[MBQC how-to](../../../docs/src/howto/purificationmbqc.md) for trajectory statistics
and model assumptions. `QS_TESTRUN=true` gives the interactive script a bounded run.
The second dashboard, `sweep.jl`, shares controls and trajectory plots through
`interactive_controls.jl`. It runs 1,000 trials at each of 11 slider values,
publishes only complete batches, and restarts on slider/radio changes to avoid
mixing configurations. Its wrapper checks full batches, rates, missing fidelity,
automatic scales, clearing, pause/resume, and selection changes. The bounded
script path uses two settings with five trials each. Reuse the existing worktree's
`examples/` environment when checking either dashboard; no separate project is needed.
Both dashboards include a spin-capture depolarization slider, also available for
sweeps. It mixes the heralded Genqo pair with the maximally mixed state before
Clifford sampling, preserving the heralding probability and local source.
Tests compare this channel with the full two-qubit Pauli average and exercise
live slider snapshots and capture-noise sweeps. See the how-to for its convention.
The shared Hadamard toggle selects the first or second endpoint of each local
graph edge; the second endpoint preserves the original default. Numeric sliders
remain the only sweep candidates. Snapshots include the placement, and changing
it restarts a sweep with the same pause/in-flight-result rules as slider edits.
Tests compare both Clifford frames with the raw source density matrix and check
ideal trajectories, live placement changes, and sweep invalidation. The how-to
explains why the two placements route resource noise differently.

Tutorial-local setup and helper functions are not a supported library API. Public
QuantumSavory APIs demonstrated by examples remain governed by the package contract,
and every checked-in example must remain executable across compatible versions.

## Anchors

- **Source:** [`examples/`](../../../examples/) and [`examples/Project.toml`](../../../examples/Project.toml) — runnable scripts and their environment.
- **Docs:** [`docs/src/howto.md`](../../../docs/src/howto.md) and [`docs/src/tutorial.md`](../../../docs/src/tutorial.md) — human entry points.
- **Test:** [`test/examples/`](../../../test/examples/) and [`test/runtests.jl`](../../../test/runtests.jl)
- **CI:** [`.buildkite/pipeline.yml`](../../../.buildkite/pipeline.yml) — separate example and plotting shards.

## Known coverage gaps

No discoverable wrapper directly includes
`congestionchain/3_aggregate_of_multiple_simulations.jl`,
`graphstate/graph_preparer.jl`, or `states_rest_server/server.jl`. The latter two may be
helper/service entry points, but the current suite does not yet demonstrate the
all-checked-in-examples criterion. Most existing wrappers remain smoke tests.

Example dependency audits must count documented backend and protocol authoring seams as
public APIs, including `AbstractProtocol`, logging-context overloads, and the register
backend interface. The remaining concrete boundary violations are direct reads of
unstable `_log` or `_backlog` protocol bookkeeping in repeater-grid and simple-switch
code, plus the exported but undocumented `nongreedymultilock` used by the color-center
cluster setup. These remain coverage and compatibility gaps even when they pass against
the same checkout.
