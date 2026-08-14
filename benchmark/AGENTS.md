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