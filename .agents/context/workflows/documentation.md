# Documentation

- **Context need:** Task playbook
- **Open when:** Editing human docs, docstrings, navigation, doctests, or deployment configuration.
- **Do not open when:** A source-only change has no public explanation or documentation validation impact.
- **Review when:** `docs/make.jl`, docs dependencies, plotting doctests, or Buildkite documentation steps change.

## Change and validate documentation

1. Place concepts, tutorials, how-to guides, and API reference in their existing
   Diátaxis-oriented sections. Update `docs/make.jl` navigation when adding a page.
   Each page under `docs/outdated/` is labeled archival, so filesystem presence is not
   proof that a page is published.
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

Human docs are part of the product contract and the detailed API catalog. A Julia API is
public only when generated prose documents it and source either exports it or marks it
`public`. A dependency-owned name intentionally reexported and documented through
QuantumSavory is part of that product surface; dependency internals that the package does
not expose are not. A documented constructor parameter is public, but the concrete field
that stores it remains internal even when it has the same name. The interactive metadata
catalogs, `ProtocolZoo.AbstractProtocol`, `ProtocolZoo.permits_virtual_edge`, and the
protocol catalog trait now use targeted `public` declarations. The remaining
public-intent inventory is:

- generated prose but no marking: qualified `stateof`, `quantumstate`, `swap!`,
  `showmetadata`, `default_repr`, `Switches.promponas_bruteforce_choice`,
  `ProtocolZoo.EntanglementDelete`, `ProtocolZoo.QTCP.QDatagramSuccess`, the three Zoo
  module bindings, their documented `Genqo`/`Switches`/`QTCP`/MBQC nested modules, and
  the two Genqo state models; and
- source docstring but no generated prose or marking: `slots`,
  `CircuitZoo.AbstractCircuit`, and its incomplete `inputqubits` feature interface.

Audit those gaps instead of treating documentation alone or an accidental export alone
as sufficient. The Zoo catalogs give the model and feature details.

Every checked-in human-documentation file and example is part of the product contract.
Published pages must build; unpublished drafts and archives must be explicitly
classified and must not silently contradict the maintained contract. Agent context
should link to human docs and record current implementation boundaries, not copy their
signatures and examples.

At this audit revision, `docs/src/` has 45 Markdown content pages, and all 45 are listed
in the Documenter page tree.
`docs/outdated/` has two individually labeled archival content pages. Recount this
inventory when navigation or Markdown files change.

Navigation classification applies to human prose pages. `docs/make.jl`,
`docs/Project.toml`, CSS, the bibliography, and referenced image/video assets are
documentation-support artifacts: validate them through build, link, citation, and
rendering success, not as standalone pages or exact-content promises. `docs/AGENTS.md`
is an agent router rather than human product prose. The congestion-chain MP4 and
statistics PNG are currently unreferenced retained example outputs; their presence and
exact bytes are not a rendering-content promise.

## Anchors

- **Source:** [`docs/make.jl`](../../../docs/make.jl) and [`docs/Project.toml`](../../../docs/Project.toml) — build, external integration, navigation, and deployment.
- **Docs:** [`docs/src/index.md`](../../../docs/src/index.md), [`docs/src/register_networks.md`](../../../docs/src/register_networks.md), and [`docs/outdated/message_queues.md`](../../../docs/outdated/message_queues.md) — published entry point, published explanation, and archival classification.
- **Test:** [`test/plotting/doctests_tests.jl`](../../../test/plotting/doctests_tests.jl) — the separately executed docstring doctests.
- **CI:** [`.buildkite/pipeline.yml`](../../../.buildkite/pipeline.yml) — credentials and full-build invocation.

## Unresolved questions

- Should `docs/make.jl` gain explicit offline, no-embedding, and no-deploy modes?
- Should Markdown-page doctests be enabled in a separate safe job?
