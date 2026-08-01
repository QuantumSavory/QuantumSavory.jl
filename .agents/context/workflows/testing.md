# Testing

- **Context need:** Task playbook
- **Open when:** Selecting local checks, adding a test file, or interpreting CI shard coverage.
- **Do not open when:** Only reasoning about product behavior without running or changing verification.
- **Review when:** `test/runtests.jl`, test projects, workspace membership, or CI shard configuration changes.

## Select and run checks

1. Add discoverable tests with a filename ending `_tests.jl`. The
   ParallelTestRunner entry point finds Julia tests, then filters out every name without
   that suffix. `test/test_stateszoo_depolarized.jl` is currently orphaned by
   this rule despite containing a test item.
2. Run the smallest named test or prefix first through the package test entry point,
   then its shard. With no arguments the runner explicitly defaults to `general`.
   Prefixes route `plotting` tests to `test/projects/plotting`, `examples` tests to the
   top-level `examples` project, and `jet` to `test/projects/jet`; JET executes directly
   while other tests use ParallelTestRunner.
3. Finish cross-cutting changes with general tests. Record the command and actual
   outcome; repository configuration and historical CI jobs are not evidence that a
   current checkout passes.
4. Run specialist shards when relevant. Buildkite defines general on stable and alpha,
   plus JET, examples, plotting, and docs. GitHub’s main CI runs only general on Linux
   x64 with five threads, macOS arm64 with one, and Windows x64 with one. The downgrade
   workflow runs general on Julia 1.12 and excludes Aqua through the runner’s downgrade
   condition.
5. Check environment routing before diagnosing dependency failures. Root workspace
   membership names nonexistent `test/projects/examples`, while the runner correctly
   uses `examples/`. Do not “fix” resolution by creating the missing directory.

The default general shard and CI scope leave plotting, examples, JET, and docs as
separate evidence. Report them independently rather than summarizing all verification
as “tests pass.” Combinations declared and exercised by CI form the current supported
compatibility matrix; inspect the actual job, environment, and selector before extending
that claim.

## Known coverage gaps

- No single end-to-end fixture combines directional delays, noisy quantum transport,
  chronological background evolution, and final-resource assertions. Representation
  reuse/promotion and asynchronous protocol composition are likewise split across tests.
- Core tests do not exhaustively traverse ownership/removal layouts or jointly cover
  reduction order and randomness, local-time evolution, the full tag/query/wait matrix,
  and causal behavior at equal timestamps.
- Network tests lack a discriminating direct-versus-forwarded routing fixture and exact
  send, pre-arrival, arrival, ownership, and reciprocal-backreference assertions for
  quantum transport.
- Zoo tests do not mechanically derive public inventories or consistently verify API
  prose, examples, constructor introspection, circuit features, and destructive effects.
  Independent external state and circuit conformance fixtures are also absent.
- Optional activation, stable log groups, renderers, and inspection APIs are sampled;
  there is no clean absent/partial/complete activation matrix or success-only renderer
  suite.
- CI has no whole-product run covering every public Zoo entry, checked-in example,
  documentation integration, and supported configuration together.

## Anchors

- **Source:** [`test/runtests.jl`](../../../test/runtests.jl) and [`Project.toml`](../../../Project.toml) — discovery, shard routing, and the workspace mismatch.
- **Docs:** [`AGENTS.md`](../../../AGENTS.md) — repository-level testing expectations.
- **Test:** [`test/general/`](../../../test/general/), [`test/plotting/`](../../../test/plotting/), and [`test/examples/`](../../../test/examples/) — discoverable shard contents.
- **CI:** [`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml), [`.github/workflows/downgrade.yml`](../../../.github/workflows/downgrade.yml), and [`.buildkite/pipeline.yml`](../../../.buildkite/pipeline.yml) — actual automation scope.

## Unresolved questions

- Should the orphaned depolarized-state file be renamed or merged into the existing API tests?
- Should the root workspace point to `examples` instead of `test/projects/examples`?
