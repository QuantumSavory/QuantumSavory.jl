# Zoo, Extension, and Observability System Requirements

## SYS-008 — Keep state, circuit, and protocol catalogs distinct and reusable

- **Normative statement:** The product shall provide distinct catalogs for
  parameterized resource-state models, immediate callable quantum routines, and
  resumable network-control protocols. Every public entry in all three catalogs shall
  be supported, documented in the generated API reference and examples, usable
  independently, and composable through shared product interfaces; internal helpers
  shall not appear as public catalog entries.
- **Parents:** STK-003, STK-004
- **Acceptance criterion:** Given an inventory of every public entry in all three
  catalogs, each entry appears in generated API documentation and an applicable
  example; each state entry initializes a resource in every representation it
  designates compatible, each circuit entry acts immediately with its declared
  features, and each protocol entry constructs with documented parameters and
  schedules as a resumable process. Representative entries from all three catalogs
  compose in one scenario, and internal helper types are absent from public discovery.
- **Verification:** SYSV-006 (test)
- **Context:** [State catalog](../../context/zoos/states-catalog.md),
  [circuit catalog](../../context/zoos/circuits-catalog.md), and
  [protocol catalog](../../context/zoos/protocols-catalog.md)

## SYS-009 — Bound the SemVer-protected public interface

- **Normative statement:** A product interface shall be public and SemVer-protected
  when it is described in generated prose documentation and is either exported or
  declared `public`; neither documentation nor namespace exposure alone makes it
  public. Documented qualified APIs shall be declared `public`; internal helpers and
  implementation or third-party extension hooks shall not be presented as public.
  Representation defaults are the sole stated exception to this protection, and a
  preceding deprecation release is not required for a breaking change.
- **Parents:** STK-004
- **Acceptance criterion:** A generated-documentation and namespace inventory finds
  every public API both documented and exported or declared `public`, including
  qualified inspection functions, and finds no internal Zoo helper or backend,
  lowering, lifecycle, logging-context, or activation hook advertised as public. Across
  a SemVer-compatible comparison, protected APIs, public tag layouts, query/wait/event
  semantics, and log-group identifiers remain compatible; representation defaults,
  nonpublic internals, log payloads, event identifiers, and rendering content may
  differ. A breaking release may remove a public interface without an earlier
  deprecation release.
- **Verification:** SYSV-007 (test)
- **Context:** [Documentation workflow](../../context/workflows/documentation.md)

## SYS-010 — Preserve log groups and provide optional rendering

- **Normative statement:** The product shall emit structured simulation diagnostics
  under documented SemVer-stable log groups and shall make built-in visualization and
  interactive inspection render successfully when their declared optional
  capabilities are available. Log events, payload fields, messages, ordering, and
  rendering content are not stable product interfaces.
- **Parents:** STK-004, STK-005
- **Acceptance criterion:** Representative core and protocol activity emits records
  selectable through every documented public log group. With each complete supported
  optional dependency set available, every public text, HTML, plotting, mapping, or
  interactive rendering entry point completes successfully; the check does not compare
  exact payloads, text, markup, layout, or image content.
- **Verification:** SYSV-008 (test)
- **Context:** [Structured logging](../../context/network/structured-logging.md)

## SYS-011 — Support declared CI and integration combinations

- **Normative statement:** The product shall operate in every Julia, operating-system,
  numerical-backend, weak-dependency, plotting, and documentation combination declared
  and selected by repository CI, while core loading shall not require optional UI
  dependencies. Supported external integrations shall operate correctly when their
  dependencies and services are available.
- **Parents:** STK-004
- **Acceptance criterion:** Tracing each declared CI matrix value and selector to its
  executed workload shows a passing product load and relevant focused behavior for
  every supported combination. A required-dependency-only environment loads core
  behavior; every complete weak-dependency set activates only its corresponding
  built-in extension; documentation and plotting environments build; and each external
  integration returns its documented result against an available test dependency or
  service.
- **Verification:** SYSV-008 (test)
- **Context:** [Optional extensions](../../context/optional-extensions.md)

## SYS-012 — Maintain human documentation and execute product examples

- **Normative statement:** Every checked-in human-documentation file shall be classified
  as published, unpublished draft, or archival and remain consistent with that
  classification; historical or draft differences from current supported behavior
  shall be explicit rather than silently contradictory. Published generated
  documentation shall describe the public API in prose and API reference, and every
  checked-in example shall execute on future SemVer-compatible product versions.
  Helpers defined only inside a tutorial or example are not public unless they
  independently satisfy the public-interface convention.
- **Parents:** STK-004
- **Acceptance criterion:** An inventory accounts for every human-documentation file;
  published pages build without unresolved public references, while drafts and archives
  are conspicuously classified and explicitly identify any known historical or planned
  difference from current supported behavior. In every declared example environment,
  every checked-in low-level and user-oriented example completes. Every public Zoo
  entry has API-reference coverage and applicable example coverage; tutorial-local
  helpers are excluded from the public inventory unless documented and exported or
  declared `public`.
- **Verification:** SYSV-009 (test)
- **Context:** [Documentation workflow](../../context/workflows/documentation.md) and
  [example workflow](../../context/workflows/examples.md)
