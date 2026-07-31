# QuantumSavory.jl Agent Router

Open the [agent documentation index](.agents/index.md) and follow the task's
narrowest route; never scan `.agents/` wholesale. Its V-model is the living,
maintainer-confirmed statement of intended product behavior, including
repository-grounded work not implemented yet. Context describes current
implementation and explicit gaps. `.agents/evals/` is unrelated evaluation
data; ignore it unless the task explicitly targets evals.

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

Replace the selector with the runner's test name or prefix, such as
`general/querywait`; omit `test/`, `_tests`, and `.jl`. Use the normal suite when
the change crosses subsystem boundaries:

```sh
julia --project=. -e 'using Pkg; Pkg.test(; test_args=["general"])'
```

Before handoff, review `git diff` and `git status`, and report checks not run.
