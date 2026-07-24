# Optional Extensions

- **Context need:** Reference
- **Open when:** Checking weak-dependency activation, interactive discovery, plotting, state exploration, or map integration.
- **Do not open when:** Core behavior, headless simulation, or backend work has no optional-package dependency.
- **Related specification IDs:** SYS-010, SYS-011, SUB-014, CMP-013
- **Review when:** Project weak dependencies, extension declarations, extension methods, or plotting tests change.

## Activation boundaries

QuantumSavory declares three Julia package extensions. Core defines the public function
seams, but implementations become available only when every weak dependency named for
the extension is loaded:

- `QuantumSavoryInteractiveUtils` requires both `InteractiveUtils` and `REPL`. It
  implements discovery of slot, background, and public protocol types plus constructor
  metadata inspection.
- `QuantumSavoryMakie` requires `Makie`. It implements network/resource plotting,
  rich state and protocol PNG display, and the StatesZoo interactive state explorer.
- `QuantumSavoryTylerMakie` requires both `Tyler` and `Makie`. It implements geographic
  map generation used with network plots.

Do not add optional packages to core `using` statements or assume an extension method
exists after loading only QuantumSavory. User-facing examples should import a concrete
Makie backend where rendering is needed. Headless validation generally uses CairoMakie;
interactive examples may require GLMakie or WGLMakie and a display/runtime appropriate
to that backend.

The plotting extension emits diagnostics under `LOG_GROUPS.visualization`. The group is
part of the stable group set, while individual visualization event fields remain
representative rather than a complete versioned schema.

Extension testing lives in the plotting project, whose `[sources]` entry resolves
QuantumSavory from the repository root. The plotting shard covers Cairo/GL behavior,
maps, coordinates, tag/observable displays, PNG output, and module docstring doctests.
This evidence is separate from general CI; GitHub’s main matrix runs only the general
shard, while Buildkite has a distinct plotting job.

## Anchors

- **Source:** [`Project.toml`](../../Project.toml), [`ext/QuantumSavoryInteractiveUtils/QuantumSavoryInteractiveUtils.jl`](../../ext/QuantumSavoryInteractiveUtils/QuantumSavoryInteractiveUtils.jl), [`ext/QuantumSavoryMakie/QuantumSavoryMakie.jl`](../../ext/QuantumSavoryMakie/QuantumSavoryMakie.jl), and [`ext/QuantumSavoryTylerMakie/QuantumSavoryTylerMakie.jl`](../../ext/QuantumSavoryTylerMakie/QuantumSavoryTylerMakie.jl) — activation and methods.
- **Docs:** [`docs/src/visualizations.md`](../../docs/src/visualizations.md), [`docs/src/state_visualization.md`](../../docs/src/state_visualization.md), and [`docs/src/tutorial/state_explorer.md`](../../docs/src/tutorial/state_explorer.md) — public optional features.
- **Test:** [`test/projects/plotting/Project.toml`](../../test/projects/plotting/Project.toml) and [`test/plotting/`](../../test/plotting/) — extension environment and focused coverage.

## Unresolved questions

- Which extension APIs beyond activation and log groups should be treated as stable?
- Should interactive discovery tolerate protocol types without the expected `sim`/`net` field layout?
