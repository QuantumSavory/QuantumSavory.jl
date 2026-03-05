# QuantumSavory.jl

QuantumSavory.jl is a full-stack simulator for quantum hardware and quantum
networks (quantum dynamics, classical control, message passing, event
simulation, and protocol modeling).

Documentation: https://qs.quantumsavory.org/dev/

## Repository Landmarks

- `src/` core package code
- `src/CircuitZoo/`, `src/ProtocolZoo/`, `src/StatesZoo/` domain libraries
- `ext/` optional extensions (`QuantumSavoryMakie`, `QuantumSavoryTylerMakie`, `QuantumSavoryInteractiveUtils`)
- `test/` full test suite
- `examples/` example workflows
- `docs/` Documenter sources
- `benchmark/` benchmarks

## QuantumSavory-Specific Commands

```bash
# Instantiate package environment
julia -tauto --project=. -e "using Pkg; Pkg.instantiate()"

# Default tests
julia -tauto --project=. -e "using Pkg; Pkg.test()"

# JET-only tests
JET_TEST=true julia -tauto --project=. -e "using Pkg; Pkg.test()"

# Example tests
QUANTUMSAVORY_EXAMPLES_TEST=true julia -tauto --project=. -e "using Pkg; Pkg.test()"

# Example+plot tests (headless)
QUANTUMSAVORY_EXAMPLES_PLOT_TEST=true DISPLAY=:0 xvfb-run -e /dev/null -s '-screen 0 1024x768x24' julia -tauto --project=. -e "using Pkg; Pkg.test()"

# Plot tests (headless)
QUANTUMSAVORY_PLOT_TEST=true DISPLAY=:0 xvfb-run -e /dev/null -s '-screen 0 1024x768x24' julia -tauto --project=. -e "using Pkg; Pkg.test()"

# Build docs
julia -tauto --project=docs -e "using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()"
julia -tauto --project=docs docs/make.jl
```

Rules:
- Do not run individual `test/*.jl` files directly; use `Pkg.test()`.
- Do not edit `Manifest*.toml` manually.

## Use Installed Skills For Generic Workflow

The workspace already includes reusable Julia skills. Prefer those instead of
duplicating process details here:

- `julia-package-dev` for package development setup and dependency management
- `julia-tests-run` and `julia-tests-write` for test execution and test authoring
- `julia-docs`, `julia-docstrings`, `julia-doctests`, `julia-doccitations` for docs work
- `julia-github` for remotes, branching, and PR workflow
- `julia-multipackage` for coordinated multi-repo development
- `julia-pkgextension` and `julia-makie-recipes` for extension and plotting work
- `julia-bench-quick`, `julia-bench-write`, `julia-bench-run` for benchmarking
- `whitespace` for whitespace/newline cleanup
