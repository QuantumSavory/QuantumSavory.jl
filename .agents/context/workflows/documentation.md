# Documentation

- **Context need:** Task playbook
- **Open when:** Editing human docs, docstrings, navigation, doctests, or deployment configuration.
- **Do not open when:** A source-only change has no public explanation or documentation validation impact.
- **Related specification IDs:** SYS-009, SYS-011, SYS-012
- **Review when:** `docs/make.jl`, docs dependencies, plotting doctests, or Buildkite documentation steps change.

## Change and validate documentation

1. Place concepts, tutorials, how-to guides, and API reference in their existing
   Diátaxis-oriented sections. Update `docs/make.jl` navigation when adding a page.
   `docs/src/howto/repeatergrid/repeatergrid.md` currently exists but is omitted from
   the page list, so filesystem presence is not proof that a page is published.
2. Keep runnable docstrings compatible with the plotting doctest setup. The main
   `makedocs` call sets `doctest=false`; it does not execute documentation-page
   `jldoctest` blocks. A separate plotting test calls `doctest(QuantumSavory)`, which
   exercises module docstrings using a broader setup.
3. Run focused examples or doctests before attempting the full build. There is no
   isolated offline docs command today: `docs/make.jl` always calls the external
   AnythingLLM service, builds, and then invokes Buildkite-configured deployment.
4. Treat the full build as credentialed and externally coupled. Buildkite supplies
   `ANYTHINGLLM_API_KEY` and `DOCUMENTER_KEY`; a local run without intended credentials
   or deployment authority is not a safe approximation. Do not claim the docs build
   was validated if only Markdown links or a focused doctest were checked.
5. When the build machinery changes, separate three outcomes in reporting:
   content generation, external embedding integration, and deployment. A failure in one
   does not establish the status of the others.

Human docs are part of the product contract and the detailed API catalog. Under SYS-009,
a Julia API is public only when generated prose documents it and source either exports
it or marks it `public`. A documented constructor parameter is public, but the concrete
field that stores it remains internal even when it has the same name. This checkout
contains no `public` declarations, despite prose-documented unexported functions such as
`stateof` and qualified standard protocol tags. Audit those gaps instead of treating
documentation alone or an accidental export alone as sufficient.

Generated pages and all checked-in examples are covered by SYS-012. Agent context should
link to human docs and record current implementation boundaries, not copy their
signatures and examples.

## Anchors

- **Source:** [`docs/make.jl`](../../../docs/make.jl) and [`docs/Project.toml`](../../../docs/Project.toml) — build, external integration, navigation, and deployment.
- **Docs:** [`docs/src/index.md`](../../../docs/src/index.md) and [`docs/src/howto/repeatergrid/repeatergrid.md`](../../../docs/src/howto/repeatergrid/repeatergrid.md) — published entry and omitted-page evidence.
- **Test:** [`test/plotting/doctests_tests.jl`](../../../test/plotting/doctests_tests.jl) — the separately executed docstring doctests.
- **CI:** [`.buildkite/pipeline.yml`](../../../.buildkite/pipeline.yml) — credentials and full-build invocation.

## Unresolved questions

- Should `docs/make.jl` gain explicit offline, no-embedding, and no-deploy modes?
- Is the repeater-grid page intentionally unpublished?
- Should Markdown-page doctests be enabled in a separate safe job?
