# System Quality and Inspection Verification

These actions cover package-level diagnostics, compatibility, documentation, examples,
and inspection behavior.

## SYSV-008 — Verify diagnostics, optional UI, and compatibility

- **Covers:** SYS-010, SYS-011
- **Method:** test
- **Procedure:** Run each declared CI compatibility configuration, test core-only load
  and absent/partial/complete weak-dependency sets, capture every stable log group, and
  invoke each supported renderer and available built-in integration.
- **Environment / configuration:** [`Project.toml`](../../../Project.toml) compatibility,
  isolated projects, and configured CI platforms.
- **Pass criterion:** Core loading and operations succeed without optional UI
  dependencies in every CI-declared Julia/platform/backend/dependency combination.
  Each complete weak-dependency set activates its corresponding repository-owned
  feature and incomplete sets do not; integrations operate correctly when their
  dependencies or configured services are available. Representative records use their
  documented stable log groups, and every supported renderer completes. No log payload
  or rendered content is compared.
- **Status:** implemented
- **Evidence:** [`Project.toml`](../../../Project.toml), [`ci.yml`](../../../.github/workflows/ci.yml), [`downgrade.yml`](../../../.github/workflows/downgrade.yml), [`pipeline.yml`](../../../.buildkite/pipeline.yml), [`logging_tests.jl`](../../../test/general/logging_tests.jl), [`interactiveutils_tests.jl`](../../../test/general/interactiveutils_tests.jl), [`show_html_tests.jl`](../../../test/general/show_html_tests.jl), [`protocol_show_html_contracts_tests.jl`](../../../test/general/protocol_show_html_contracts_tests.jl), [`cairo_tests.jl`](../../../test/plotting/cairo_tests.jl), [`gl_tests.jl`](../../../test/plotting/gl_tests.jl), [`show_png_tests.jl`](../../../test/plotting/show_png_tests.jl), [`doctests_tests.jl`](../../../test/plotting/doctests_tests.jl)
- **Nonconformance:** No clean absent/partial/complete activation matrix exists;
  log groups and renderers are sampled, the documentation integration needs credentials
  and an external service, and only the general shard is cross-platform.

## SYSV-009 — Verify generated documentation and executable examples

- **Covers:** SYS-012
- **Method:** test
- **Procedure:** Build the generated human documentation, map every checked-in example
  entry point to a discoverable CI wrapper or bounded test mode, and run the complete
  docs and examples shards against a SemVer-compatible package revision.
- **Environment / configuration:** Documentation and examples projects with declared
  dependencies; configured services available for the full docs integration.
- **Pass criterion:** Documentation generation completes; every checked-in example
  executes through CI without relying on unsupported tutorial-local helpers; and the
  same examples run on any SemVer-compatible QuantumSavory version admitted by their
  declared environment. Published examples use only public package APIs.
- **Status:** implemented
- **Evidence:** [`make.jl`](../../../docs/make.jl), [`pipeline.yml`](../../../.buildkite/pipeline.yml), [`runtests.jl`](../../../test/runtests.jl), [`examples`](../../../test/examples), [`Project.toml`](../../../examples/Project.toml)
- **Nonconformance:** The examples shard has many smoke wrappers but no durable audit
  maps every checked-in script, interactive path, and server to a bounded test. It is
  not run across the full compatible-version range, and the credentialed docs build has
  no isolated integration test.

## SYSV-010 — Verify public inspection and network metadata

- **Covers:** SYS-013
- **Method:** test
- **Procedure:** Inspect shared register state through every documented public
  inspection function, then inspect indexed topology and vertex, undirected-edge,
  directed-edge, and bulk metadata through public boundaries; invoke renderers only as
  success probes.
- **Environment / configuration:** Root tests with multiple registers, one shared state,
  and unequal opposing directed values.
- **Pass criterion:** Inspection reports assignment, shared ownership, and native state
  without mutation; graph/index queries reproduce topology, registers, and slots;
  metadata round-trips; undirected lookup is endpoint-order invariant, opposing directed
  values remain distinct, and bulk access or assignment covers the existing vertex or
  edge collection. Each supported renderer completes, with no content comparison.
- **Status:** implemented
- **Evidence:** [`observable_tests.jl`](../../../test/general/observable_tests.jl), [`show_html_tests.jl`](../../../test/general/show_html_tests.jl), [`show_gabs_tests.jl`](../../../test/general/show_gabs_tests.jl), [`registernet_interface_tests.jl`](../../../test/general/registernet_interface_tests.jl), [`registernet_metadata_access_tests.jl`](../../../test/general/registernet_metadata_access_tests.jl)
- **Nonconformance:** Network tests cover most addressing modes, but both directed bulk
  setters currently dispatch into the undirected store. No fixture covers every
  documented state inspection function and metadata mode; the unexported inspection
  functions also lack `public` declarations.
