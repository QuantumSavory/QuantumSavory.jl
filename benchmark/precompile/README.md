# Cold-start benchmark

This harness compares package-cache build, import, and first-use latency. It is
separate from the BenchmarkTools and AirspeedVelocity suite, which measures
steady-state operations after QuantumSavory is loaded.

From the repository root, give the harness a new output directory plus two or
more `label=checkout` variants:

```sh
benchmark/precompile/run.sh results \
    base=/path/to/base/QuantumSavory.jl \
    head=/path/to/head/QuantumSavory.jl
```

The first variant is the default baseline. Each variant must be a clean,
committed checkout, and all variants must have identical `Project.toml` files.
The harness refuses to overwrite existing result files. It resolves one
consumer Manifest and points it at each checkout in turn. It creates one seed
depot with dependency caches and a new writable depot for every QuantumSavory
package-cache build. Dependency setup may access package servers. After setup,
cache builds and samples run with package offline mode enabled.

Variant labels and scenario names must start with an ASCII letter or digit and
contain only ASCII letters, digits, dots, underscores, or hyphens. This keeps
the comma-separated controls, TSV output, metadata keys, and Markdown output
unambiguous.

Use environment variables to select the amount of work and the comma-separated
scenario list:

```sh
QS_PRECOMPILE_BUILDS=5 \
QS_PRECOMPILE_SAMPLES=4 \
QS_PRECOMPILE_SCENARIOS=bell,entangler \
benchmark/precompile/run.sh results base=/path/to/base head=/path/to/head
```

Use five cache builds and four recorded samples for reportable candidate
measurements. The default of one build and two samples is intended only for
smoke tests. Supported scenarios are `bell`, `bell_core`, `measurement`,
`clifford`, `metadata`, `classical_transport`, `quantum_transport`,
`circuitzoo`, `stateszoo`, `entangler`, `quantummc`, and `gabs`.

For a multi-candidate experiment, use `QS_PRECOMPILE_EXTRA_SCENARIOS` to run a
motivating scenario only for its named variant and for the baseline. This keeps
the common headline scenarios on every variant:

```sh
QS_PRECOMPILE_SCENARIOS=bell,entangler \
QS_PRECOMPILE_EXTRA_SCENARIOS=metadata=metadata,channel=quantum_transport \
benchmark/precompile/run.sh results \
    base=/path/to/base metadata=/path/to/metadata channel=/path/to/channel
```

By default, the first variant is the baseline for every candidate. Use
`QS_PRECOMPILE_BASELINES` when candidates need different baselines, such as a
cumulative experiment in which every stage is compared with the preceding
stage:

```sh
QS_PRECOMPILE_BASELINES=stage2=stage1,stage3=stage2 \
benchmark/precompile/run.sh results \
    base=/path/to/base \
    stage1=/path/to/stage1 \
    stage2=/path/to/stage2 \
    stage3=/path/to/stage3
```

The default scenarios are `bell` and `entangler`. Each scenario also gets one
discarded filesystem warm-up per build. The harness fixes Julia,
package-precompile, BLAS, and OpenMP thread counts to one; disables startup and
history files; and uses `JULIA_LOAD_PATH=@:@stdlib`. It requires GNU/Linux and
Julia 1.12.6. Set `JULIA` to select that Julia executable. A different Julia
version or a dirty checkout is allowed only for a non-reportable smoke run by
setting `QS_PRECOMPILE_ALLOW_JULIA_MISMATCH=1` or
`QS_PRECOMPILE_ALLOW_DIRTY=1`, respectively.

Each candidate gets a separate comparison. For every build number, its mapped
baseline cache and samples run immediately before the candidate cache and
samples. Thus, material-change counts pair nearby, independent cache builds.

The output directory contains `raw.tsv`, the per-build `build-summary.tsv`, the
aggregate `summary.tsv`, the rendered `summary.md`, `metadata.txt`, and the
resolved `consumer-Project.toml` and `consumer-Manifest.toml`. The aggregate
summary reports medians, interquartile ranges, and the number of builds with a
material total-latency change. A material change is at least 50 ms and 5% is
used when it is larger. Performance differences are descriptive; scenario
assertion, package-cache, dependency-control, or harness failures return a
nonzero status.

The copied Manifest uses `__QUANTUMSAVORY_CHECKOUT__` as a path placeholder;
replace it with the checkout used for reproduction. The `manifest_sha256`
metadata field hashes this normalized copy. The metadata also records the
pre-normalization Manifest hash, harness commit, and harness file hashes.

See the [Julia command-line reference](https://docs.julialang.org/en/v1/manual/command-line-interface/)
for the compilation controls and the [PrecompileTools workload guide](https://julialang.github.io/PrecompileTools.jl/stable/)
for workload design.
