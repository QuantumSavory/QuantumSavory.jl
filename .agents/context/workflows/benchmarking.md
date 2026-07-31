# Benchmarking

- **Context need:** Task playbook
- **Open when:** Adding a benchmark, running a focused measurement, or interpreting benchmark automation.
- **Do not open when:** Establishing functional correctness or investigating behavior without a performance question.
- **Related specification IDs:** None — repository-only workflow
- **Review when:** Benchmark suite groups, environment resolution, or the AirspeedVelocity workflow changes.

## Measure performance

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

The GitHub workflow runs AirspeedVelocity on pull-request heads and can write to pull
requests. It is characterization infrastructure: the repository defines no checked-in
regression threshold or pass/fail performance budget. Severe regressions still warrant
maintainer investigation rather than being dismissed for lack of a formal budget.
Because the workflow uses
`pull_request_target` with `pull-requests: write`, do not describe replaying the workflow
against untrusted changes as a safe local validation recipe.

## Anchors

- **Source:** [`benchmark/benchmarks.jl`](../../../benchmark/benchmarks.jl), [`benchmark/Project.toml`](../../../benchmark/Project.toml), and [`benchmark/AGENTS.md`](../../../benchmark/AGENTS.md) — entry point, environment, and mutation conventions.
- **Docs:** [`README.md`](../../../README.md) — repository-level project context; no normative performance budget is declared.
- **Test:** [`benchmark/benchmark_tagquery.jl`](../../../benchmark/benchmark_tagquery.jl) and [`benchmark/benchmark_quantumstates.jl`](../../../benchmark/benchmark_quantumstates.jl) — representative scalar and state benchmarks.
- **CI:** [`.github/workflows/benchmark.yml`](../../../.github/workflows/benchmark.yml) — AirspeedVelocity trigger and permissions.

## Unresolved question

- Should benchmark automation avoid `pull_request_target` write permissions?
