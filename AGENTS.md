# QuantumSavory.jl Agent Router

Open the [agent documentation index](.agents/index.md), then follow only the
route needed for the task. Do not scan `.agents/` wholesale. The V-model records
the intended and implemented contract; context pages explain the implementation.
`.agents/evals/` is evaluation data, not repository guidance, and must remain
outside documentation maintenance unless the task explicitly concerns evals.

## Route by work area

- Core source: follow [src/AGENTS.md](src/AGENTS.md).
- Tests: follow [test/AGENTS.md](test/AGENTS.md).
- Human documentation: follow [docs/AGENTS.md](docs/AGENTS.md).
- Executable examples: follow [examples/AGENTS.md](examples/AGENTS.md).
- Benchmarks: follow [benchmark/AGENTS.md](benchmark/AGENTS.md).
- Optional package extensions: follow [ext/AGENTS.md](ext/AGENTS.md).

Read `Project.toml` before changing dependencies, compatibility, extensions, or
the Julia version. Preserve the existing four-space Julia indentation and update
human docs when public behavior changes.

## Verification

Run focused tests first from the repository root:

```sh
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["general/register_interface"])'
```

Replace the test selector with the affected `test/` path. Use the normal suite
when the change crosses subsystem boundaries:

```sh
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["general"])'
```

Before handoff, review `git diff` and `git status`, and report checks not run.
