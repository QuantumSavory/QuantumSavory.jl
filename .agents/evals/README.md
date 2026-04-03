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

## Evaluator Script

This folder also contains `evaluate_anythingllm.jl`, a Julia script for
running the eval corpus against an AnythingLLM workspace and grading the
returned answers with `codex exec`.

The evaluator:

- loads all `*-Q.md`, `*-A.md`, and `.yaml` entries in this folder
- creates a fresh AnythingLLM thread per prompt
- queries `/v1/workspace/{slug}/thread/{threadSlug}/chat`
- deletes each thread after use
- switches models between batches with `/v1/system/update-env`
- stores one CSV row per `(model, prompt)` pair
- can optionally render bar plots for grade counts, total score, and runtime

### Usage Notes

- Some AnythingLLM deployments expose the active model as `LLMModel` in
  `/v1/system`, but the writable setting key can still be provider-specific.
  The script defaults to `--model-setting-key auto` and maps the current
  provider to the correct writable preference key when possible.
- If automatic model switching does not work, use
  `--manual-model-switch fallback` or `--manual-model-switch always` and the
  script will pause and wait for the user to switch the model manually.
- The script strips `<think>...</think>` blocks before sending answers to the
  evaluator by default. Pass `--keep-think-tags` to grade the raw answer text.

### Example Command

```bash
julia --project=.agents/evals .agents/evals/evaluate_anythingllm.jl \
  --api-base-url https://anythingllm.example.org/api \
  --api-token YOUR_TOKEN \
  --workspace-slug quantumsavory-dev \
  --llm deepseek-r1:8b \
  --setting LLMProvider=ollama \
  --plot
```
