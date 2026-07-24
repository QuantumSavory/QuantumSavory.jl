# Source Router

Open only the context for the code being changed:

- Registers, operations, representations, tags, queries, or waits:
  [core context](../.agents/context/core/index.md).
- Backgrounds, time advancement, or simulator representations:
  [simulation context](../.agents/context/simulation/index.md).
- Register networks, messages, or quantum channels:
  [network context](../.agents/context/network/index.md).
- `StatesZoo`, `CircuitZoo`, or `ProtocolZoo`: use that subtree's `AGENTS.md`.
- Optional loading or visualization hooks:
  [extension context](../.agents/context/optional-extensions.md).

Use the matching component contract and verification action linked from the
context page. Keep backend capability limits explicit; dispatch failure is not
evidence that a representation is supported.

Run the narrowest matching `test/general/*_tests.jl` selector from the repository
root before the full `general` suite.
