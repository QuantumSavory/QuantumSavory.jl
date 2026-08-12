# Benchmarking

- **Context need:** Task playbook
- **Open when:** Adding a benchmark, running a focused measurement, or interpreting benchmark automation.
- **Do not open when:** Establishing functional correctness or investigating behavior without a performance question.
- **Review when:** Benchmark suite groups, environment resolution, or the AirspeedVelocity workflow changes.

## Measure steady-state performance

1. Start from `benchmark/benchmarks.jl`. It loads shared dependencies, creates `SUITE`,
   obtains the current QuantumSavory version from the active manifest, and includes the
   family files.
2. Place new measurements under one of the existing top-level groups—`register`,
   `tagquery`, `change_notifier`, `onchange`, `querywait`, or `quantumstates`—or justify
   a new group. Follow `benchmark/AGENTS.md`: mutating benchmarks need fresh setup,
   commonly `deepcopy`, and `evals=1`.
3. Establish correctness and representative inputs before timing. Use stable RNGs where
   randomness affects setup, and keep process/thread parameters in the benchmark label.
4. In an already instantiated benchmark environment whose manifest resolves this
   checkout, a focused run can use:
   `julia --project=benchmark -e 'include("benchmark/benchmarks.jl");
   display(run(SUITE["tagquery"]["register"]["query_exact_filo"]))'`.
   If that precondition is not met, resolve the environment deliberately and report the
   resulting manifest context; the entry point expects one.
5. Record samples, Julia version, thread count, checkout, and comparison baseline.
   Avoid interpreting a single local timing as a regression budget.

The GitHub workflow runs AirspeedVelocity on pull-request heads. It is
characterization infrastructure: the repository defines no checked-in regression
threshold or pass/fail performance budget. Severe regressions still warrant maintainer
investigation rather than being dismissed for lack of a formal budget.

## Measure cold-start performance

Use `benchmark/precompile/run.sh` when the question concerns package-cache
creation, import, or the first execution of a user workflow. The harness uses a
standalone consumer environment, one consumer Manifest, a dependency-only seed
depot, fresh writable depots for QuantumSavory cache builds, and fresh Julia
processes for recorded samples. It fixes compilation and numerical-library
thread counts to one and disables startup files, history files, package
auto-precompilation, and inherited Julia CPU-target, project, and depot
overrides. Dependency setup loads QuantumSavory through a detached
source snapshot, not a measured checkout. After deleting that package cache, the
harness gives each measured variant one discarded cache build in a fresh
overlay depot. It verifies that every discarded build emits cache bytes and
uses a role-neutral hash order. Dependency setup may use the network; discarded
and recorded cache builds and samples use package offline mode after setup.

The default scenarios are the documented Bell measurement and a deterministic
one-round `EntanglerProt` simulation. Scenario functions include
self-consistency assertions. Select repetitions and scenarios with
`QS_PRECOMPILE_BUILDS`, `QS_PRECOMPILE_SAMPLES`, and
`QS_PRECOMPILE_SCENARIOS`. Use `QS_PRECOMPILE_EXTRA_SCENARIOS` for
candidate-specific tasks and `QS_PRECOMPILE_BASELINES` for stage-specific
baselines. When an experiment spans separate harness invocations, use
`QS_PRECOMPILE_CONSUMER_PROJECT` and `QS_PRECOMPILE_CONSUMER_MANIFEST` to reuse
the first invocation's exact normalized consumer environment. See
`benchmark/precompile/README.md` for the command and output files.

Use clean committed variants, a new output directory outside every measured
checkout, five independent cache builds, and four recorded fresh processes per
scenario for reportable candidate measurements. Run timed measurements
serially. Do not remove the per-variant discarded cache warm-up: it gives every
measured source tree equivalent pre-timing filesystem exposure. The harness counterbalances
drift by reversing comparison order on even builds and alternating whether the
mapped baseline or candidate runs first; keep this schedule and its metadata
when extending the harness. Retain a candidate only if its
motivating total latency improves by at least `max(50 ms, 5%)` in at least four
builds, both headline scenarios have zero material-regression builds, and all
scenario assertions pass. Require zero first-task recompilation samples, zero
warm-call compilation or recompilation samples, and zero material warm-runtime
regression builds. First-task compilation is expected and is not a rejection
gate. Run trace instrumentation only in separate diagnostic processes. Report
the metadata, raw TSV, per-build results, aggregate medians and interquartile
ranges, and all accepted and rejected candidates. Treat a run as reportable
only when its metadata says `reportable=true`. The dirty-checkout and
Julia-version overrides always make a run non-reportable. Checkout state hashes
must remain unchanged throughout a run, including when the initial dirty state
is allowed.

The PR-only cold-start workflow compares the exact pull-request base and head,
uploads raw results, and writes medians and interquartile ranges to the job
summary. Timing deltas do not fail the job. A broken package cache, scenario
assertion, dependency-control check, or harness command does fail it. Do not
compare these results with AirspeedVelocity values: that suite measures loaded,
steady-state operations.

## Anchors

- **Source:** [`benchmark/benchmarks.jl`](../../../benchmark/benchmarks.jl), [`benchmark/Project.toml`](../../../benchmark/Project.toml), [`benchmark/precompile/run.sh`](../../../benchmark/precompile/run.sh), and [`benchmark/AGENTS.md`](../../../benchmark/AGENTS.md) — steady-state and cold-start entry points, environments, and conventions.
- **Docs:** [`README.md`](../../../README.md) — repository-level project context; no formal performance budget is declared.
- **Test:** [`benchmark/benchmark_tagquery.jl`](../../../benchmark/benchmark_tagquery.jl) and [`benchmark/benchmark_quantumstates.jl`](../../../benchmark/benchmark_quantumstates.jl) — representative scalar and state benchmarks.
- **CI:** [`.github/workflows/benchmark.yml`](../../../.github/workflows/benchmark.yml) and [`.github/workflows/precompile.yml`](../../../.github/workflows/precompile.yml) — steady-state and cold-start automation.
