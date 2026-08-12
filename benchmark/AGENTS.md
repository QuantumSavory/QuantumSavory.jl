# Benchmark Router

Open the [benchmarking workflow](../.agents/context/workflows/benchmarking.md)
and the context page for the measured subsystem.

`benchmarks.jl` owns shared imports and includes; keep related cases in the
existing `benchmark_*.jl` files. For mutating operations, isolate each sample
with `setup`, normally using `deepcopy`, and `evals=1`.

Preserve historical benchmark keys unless a migration is intentional. Treat
AirspeedVelocity comparisons as performance evidence, not behavioral tests.

## Cold-start measurements

Use `precompile/run.sh` for package-cache build, import, and first-use latency.
It runs fresh Julia processes against isolated depots and does not use
BenchmarkTools. Keep its scenario assertions deterministic and based on public
QuantumSavory APIs. Do not add cold-start measurements to `benchmarks.jl`:
AirspeedVelocity imports QuantumSavory before it measures the steady-state
suite.

Run candidate variants serially. Keep the first variant as the default
unchanged baseline, and use `QS_PRECOMPILE_BASELINES` when a cumulative stage
needs the preceding stage as its baseline. Use
`QS_PRECOMPILE_EXTRA_SCENARIOS` for candidate-specific tasks. Keep one resolved
Manifest for all variants, and report both raw TSV and the generated median/IQR
summary.
