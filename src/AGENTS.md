# Source Router

Open only the context for changed code:

- Register storage, operations, tags, queries, or waits:
  [core context](../.agents/context/core/index.md).
- Representation selection or lowering, backend code, backgrounds, or time:
  [simulation context](../.agents/context/simulation/index.md).
- Register networks, messages, or quantum channels:
  [network context](../.agents/context/network/index.md).
- `StatesZoo`, `CircuitZoo`, or `ProtocolZoo`: use that subtree's `AGENTS.md`.
- Optional loading or visualization hooks:
  [extension context](../.agents/context/optional-extensions.md).

Use the intended-behavior and known-gap guidance on the referenced context page.
Keep backend capability limits explicit; dispatch failure is not evidence that a
representation is supported.

Run its test prefix from the root—for example, `general/apply` selects
`test/general/apply_tests.jl`—before the full `general` suite.
