# Testing

- **Context need:** Task playbook
- **Open when:** Selecting local checks, adding a test file, or interpreting CI shard coverage.
- **Do not open when:** Only reasoning about product behavior without running or changing verification.
- **Related specification IDs:** SYS-012
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
as “tests pass.”

## Anchors

- **Source:** [`test/runtests.jl`](../../../test/runtests.jl) and [`Project.toml`](../../../Project.toml) — discovery, shard routing, and the workspace mismatch.
- **Docs:** [`AGENTS.md`](../../../AGENTS.md) — repository-level testing expectations.
- **Test:** [`test/general/`](../../../test/general/), [`test/plotting/`](../../../test/plotting/), and [`test/examples/`](../../../test/examples/) — discoverable shard contents.
- **CI:** [`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml), [`.github/workflows/downgrade.yml`](../../../.github/workflows/downgrade.yml), and [`.buildkite/pipeline.yml`](../../../.buildkite/pipeline.yml) — actual automation scope.

## Unresolved questions

- Should the orphaned depolarized-state file be renamed or merged into the existing API tests?
- Should the root workspace point to `examples` instead of `test/projects/examples`?
