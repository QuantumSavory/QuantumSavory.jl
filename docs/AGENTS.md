# Human Documentation Router

Open the [documentation workflow](../.agents/context/workflows/documentation.md)
and the context page for the behavior being described. Human-facing pages must
remain explanatory; `.agents/v-model/` is the normative contract.

Cross-check public claims against source and tests. Keep known capability limits
and experimental status visible. The full `docs/make.jl` path has external and
deployment integrations, so inspect `docs/make.jl` and its environment before
running it; report when it was not run.
