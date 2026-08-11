# Cold-start benchmark

This harness compares package-cache build, import, and first-use latency. It is
separate from the BenchmarkTools and AirspeedVelocity suite, which measures
steady-state operations after QuantumSavory is loaded.

Run it from any directory and give it an output directory plus two or more
`label=checkout` variants:

```sh
benchmark/precompile/run.sh results \
    base=/path/to/base/QuantumSavory.jl \
    head=/path/to/head/QuantumSavory.jl
```

The first variant is the baseline. The variants must have identical
`Project.toml` files. The harness resolves one consumer Manifest and points it
at each checkout in turn. It creates one seed depot with dependency caches and
a new writable depot for every QuantumSavory package-cache build. Package
resolution runs in offline mode after setup.

Use environment variables to select the amount of work and the comma-separated
scenario list:

```sh
QS_PRECOMPILE_BUILDS=5 \
QS_PRECOMPILE_SAMPLES=4 \
QS_PRECOMPILE_SCENARIOS=bell,entangler \
benchmark/precompile/run.sh results base=/path/to/base head=/path/to/head
```

For a multi-candidate experiment, use `QS_PRECOMPILE_EXTRA_SCENARIOS` to run a
motivating scenario only for its named variant and for the baseline. This keeps
the common headline scenarios on every variant:

```sh
QS_PRECOMPILE_SCENARIOS=bell,entangler \
QS_PRECOMPILE_EXTRA_SCENARIOS=metadata=metadata,channel=quantum_transport \
benchmark/precompile/run.sh results \
    base=/path/to/base metadata=/path/to/metadata channel=/path/to/channel
```

Defaults are one cache build, two recorded samples, and the `bell` and
`entangler` scenarios. Each scenario also gets one discarded filesystem
warm-up per build. The harness fixes Julia, package-precompile, BLAS, and OpenMP
thread counts to one; disables startup and history files; and uses
`JULIA_LOAD_PATH=@:@stdlib`. It requires GNU/Linux and Julia 1.12.6. Set
`JULIA` to select that Julia executable. A different Julia version is allowed
only for a non-reportable smoke run by setting
`QS_PRECOMPILE_ALLOW_JULIA_MISMATCH=1`.

Each candidate gets a separate comparison. For every build number, its
baseline cache and samples run immediately before the candidate cache and
samples. Thus, material-change counts pair nearby, independent cache builds.

The output directory contains raw TSV, per-build and aggregate machine-readable
summaries, a Markdown summary, environment metadata, and the resolved consumer
Project and Manifest. The aggregate summary reports medians, interquartile
ranges, and the number of builds with a material total-latency change. A
material change is at least 50 ms and 5% is used when it is larger. Performance
differences are descriptive; scenario assertion, package-cache,
dependency-control, or harness failures return a nonzero status.

The copied Manifest uses `__QUANTUMSAVORY_CHECKOUT__` as a path placeholder;
replace it with the checkout used for reproduction. The metadata records the
SHA-256 hash of the resolved Manifest before this replacement.

See the [Julia command-line reference](https://docs.julialang.org/en/v1/manual/command-line-interface/)
for the compilation controls and the [PrecompileTools workload guide](https://julialang.github.io/PrecompileTools.jl/stable/)
for workload design.
