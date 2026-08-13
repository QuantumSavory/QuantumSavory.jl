# Optional Extensions

- **Context need:** Reference
- **Open when:** Checking weak-dependency activation, interactive discovery, plotting, state exploration, or map integration.
- **Do not open when:** Core behavior, headless simulation, or backend work has no optional-package dependency.
- **Review when:** Project weak dependencies, extension declarations, extension methods, or plotting tests change.

## Activation boundaries

QuantumSavory declares three Julia package extensions. Documented, exported user calls
become available only when every weak dependency named for the extension is loaded.
Those callable APIs are supported for their declared dependency combinations; the
generated extension-module names and package-loading machinery are implementation
details:

- `QuantumSavoryInteractiveUtils` requires both `InteractiveUtils` and `REPL`. It
  recursively discovers public concrete slot and background types from all loaded
  packages, inspects documented constructor fields, and catalogs public protocols that
  opt in through `ProtocolZoo.protocol_catalog_metadata`. Discovery is recomputed on
  each call rather than cached in a registry.
- `QuantumSavoryMakie` requires `Makie`. It implements network/resource plotting,
  rich state and protocol PNG display, and the StatesZoo interactive state explorer.
- `QuantumSavoryTylerMakie` requires both `Tyler` and `Makie`. It implements geographic
  map generation used with network plots.

Do not add optional packages to core `using` statements or assume an extension method
exists after loading only QuantumSavory. User-facing examples should import a concrete
Makie backend where rendering is needed. Headless validation generally uses CairoMakie;
interactive examples may require GLMakie or WGLMakie and a display/runtime appropriate
to that backend.

Core error-hint registration adds activation guidance for plotting, maps, and selected
interactive-discovery seams. It does not cover every unimplemented optional function,
including the state-explorer seams and `available_protocol_types`; uniform activation
diagnostics are not a current contract.

The plotting extension emits diagnostics under `LOG_GROUPS.visualization`. The group is
part of the stable group set; no other visualization log detail is stable.

Optional visualization integrations promise successful rendering for their supported
dependency combinations, not exact text, markup, layout, or pixels. Some tests make
exact tooltip, text, or HTML assertions as implementation-level regression checks;
those assertions do not turn the compared content into a SemVer-protected interface.

Extension testing lives in the plotting project, whose `[sources]` entry resolves
QuantumSavory from the repository root. The plotting shard covers Cairo/GL behavior,
maps, coordinates, tag/observable displays, PNG output, and module docstring doctests.
This evidence is separate from general CI; GitHub’s main matrix runs only the general
shard, while Buildkite has a distinct plotting job.

## Anchors

- **Source:** [`Project.toml`](../../Project.toml), [`ext/QuantumSavoryInteractiveUtils/QuantumSavoryInteractiveUtils.jl`](../../ext/QuantumSavoryInteractiveUtils/QuantumSavoryInteractiveUtils.jl), [`ext/QuantumSavoryMakie/QuantumSavoryMakie.jl`](../../ext/QuantumSavoryMakie/QuantumSavoryMakie.jl), and [`ext/QuantumSavoryTylerMakie/QuantumSavoryTylerMakie.jl`](../../ext/QuantumSavoryTylerMakie/QuantumSavoryTylerMakie.jl) — activation and methods.
- **Docs:** [`docs/src/visualizations.md`](../../docs/src/visualizations.md), [`docs/src/state_visualization.md`](../../docs/src/state_visualization.md), and [`docs/src/tutorial/state_explorer.md`](../../docs/src/tutorial/state_explorer.md) — public optional features.
- **Test:** [`test/general/interactiveutils_tests.jl`](../../test/general/interactiveutils_tests.jl), [`test/projects/plotting/Project.toml`](../../test/projects/plotting/Project.toml), and [`test/plotting/`](../../test/plotting/) — discovery, extension environments, and focused coverage.

## Known gaps

- Activation hints do not cover every unavailable optional user call.
- The prose-documented qualified `showmetadata` visualization call lacks `export` or
  `public` marking.
