# QuantumSavory Agent Evals

This folder contains evaluation cases for documentation-facing LLM agents.

Each entry uses three files:

- `<name>-Q.md`: the user prompt
- `<name>-A.md`: a strong reference answer
- `<name>.yaml`: metadata

The current dataset is staged to keep coverage broad while preserving the
project's public-vs-internal boundaries.

## Coverage Plan

1. Orientation and navigation
   - scope of the project
   - first reading path through the docs
   - where to find examples and how-tos
2. Modeling and architecture
   - symbolic frontend
   - backend choice and tradeoffs
   - registers, `RegisterNet`, factorization, time, and background noise
3. Runtime and protocol idioms
   - discrete-event processes
   - tags, queries, waiting helpers, and message buffers
   - classical versus quantum transport
4. Reusable building blocks
   - `StatesZoo`, `CircuitZoo`, and `ProtocolZoo`
   - tutorials and how-to guidance
   - visualization and debugging workflows
5. Contributor-depth checks
   - backend extension hooks
   - `StatesZoo` extension contract
   - `ProtocolZoo` review checks

## Answering Rules Captured By This Dataset

- Prefer public APIs and user-facing docs unless the prompt is clearly
  contributor-oriented.
- Be explicit about capability boundaries and common misconceptions.
- Recommend the next docs page or example when that is more useful than just
  naming an API.
- Keep code snippets small and idiomatic.
- Preserve documented caveats such as weighted states, direct-edge quantum
  channels, and `query_wait`/`querydelete_wait!` semantics.
