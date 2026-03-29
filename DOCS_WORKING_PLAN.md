# QuantumSavory.jl Documentation Working Plan

Temporary working file for the docs-improvement PR series.
Delete this file at the end of the overall documentation effort.

Branch: `docs-paper-alignment-codex`

## Documentation Principles

- Emphasize why QuantumSavory's capabilities matter, not just that they exist.
- Present the symbolic frontend as a way to avoid backend-specific mathematical
  expertise when building models.
- Present backend diversity as valuable both for performance on classical
  hardware and for support of heterogeneous physical systems beyond ideal
  qubits.
- Use "declarative noise models" and explain that backend-specific noise
  lowering is handled by the framework.
- Describe time handling as framework-managed bookkeeping, not something the
  user must wire manually throughout the model.
- When explaining modeling internals, emphasize factorized storage, declarative
  noise, and demand-driven time evolution as productivity features, not just
  implementation details.
- Describe the classical control layer as a structured metadata and messaging
  API with lego-like composability, analogous to modern classical
  infrastructure, rather than bespoke manual channel plumbing.
- Prefer language that highlights full-stack codesign, digital twins, and reuse
  across abstraction layers.
- When mentioning installation, say "latest Julia version" rather than pinning
  a specific release number in prose.

## Planned Steps

- [x] 1. Turn the Explanation, Tutorial, and Reference landing pages into real hubs with reading order and scope.
- [x] 2. Split homepage vs onboarding tutorial: keep `index.md` short and directional, and make `manual.md` the first real tutorial.
- [x] 3. Add a new "Architecture and Mental Model" explanation page as the main entry point for understanding the library.
- [x] 4. Split conceptual material from API material so Explanation stops carrying disguised reference docs.
- [x] 5. Add a "Choosing a Backend / Modeling Tradeoffs" explanation page.
- [x] 6. Move `Figs/qsavory.png` into the new architecture page and probably the homepage.
- [x] 7. Move `Figs/overview_ex.png` into a new cluster-state walkthrough / how-to landing page.
- [x] 8. Move `Figs/models.png` into the backend/modeling-tradeoffs explanation.
- [x] 9. Move `Figs/bkslider.png` into the StateZoo / state explorer docs.
- [x] 10. Move `Figs/showmethod.png` into the ProtocolZoo / visualization docs.
- [ ] 11. Move `Figs/two-way.pdf` and `Figs/one-way.pdf` into a quantum-networking background explanation. Skipped.
- [ ] 12. Move `Figs/distillation.pdf` and `Figs/correction.pdf` into that same networking background page. Skipped.
- [ ] 13. Decide whether `Figs/compare.png` belongs in a durable "Why QuantumSavory" page.
- [x] 14. Rewrite the landing-page language from the paper's introduction: codesign, digital twins, symbolic frontend, interchangeable backends.
- [x] 15. Add a "Why QuantumSavory Exists" explanation page from the related-work section.
- [ ] 16. Add a background explanation page on quantum systems: open systems, subsystem types, entanglement, and why this matters for QSavory. Skipped.
- [x] 17. Add a background explanation page on restricted formalisms: stabilizer, Gaussian, tensor-network, finite-rank / near-Clifford methods.
- [ ] 18. Add a background explanation page on networking design axes: one-way vs two-way, distillation vs error correction. Skipped.
- [ ] 19. Expand the cluster-state walkthrough into a fuller how-to guide for this full-stack example. Skipped.
- [x] 20. Add a modeling explanation page focused on register composition, factorization, lazy evolution, and declarative noise.
- [x] 21. Expand the slot-properties docs so they explain heterogeneous subsystems instead of only listing types.
- [x] 22. Expand the background-noise docs so they explain the declarative model and lazy-time semantics.
- [x] 23. Split symbolic docs into a conceptual "symbolic frontend" explanation plus retained examples/reference.
- [x] 24. Expand backend docs to cover `QuantumClifford`, `QuantumOptics`, `Gabs`, extension points, and when to choose each.
- [ ] 25. Rewrite the discrete-event docs around `@resumable`, `@process`, `AbstractProtocol`, waits, locks, and condition combinators.
- [ ] 26. Rewrite tags/queries docs around the metadata-plane idea and protocol composability.
- [ ] 27. Add a focused section or page on message buffers, classical links, routing, latency, and the locality-by-convention caveat.
- [ ] 28. Add a "Zoos as composable building blocks" explanation page.
- [ ] 29. Rewrite the state-explorer page as a real tutorial with explicit learning goals and steps.
- [ ] 30. Add a narrative CircuitZoo intro before the raw autodocs.
- [ ] 31. Add a narrative ProtocolZoo intro explaining protocol structs, composition, and visualization hooks.
- [ ] 32. Reposition visualizations as tutorial/reference material, not core explanation.
- [ ] 33. Expand the reference hub and fix nav coverage for `API_Interface.md` and `API_Symbolics.md`.
- [ ] 34. Extract only safe material from the SeQuENCe cross-comparison into docs.
- [ ] 35. Add a short "Limitations and Roadmap" page from the conclusion.
- [ ] 36. Remove or soften front-page language that says the docs are barebones and users should read source code.

## Execution Notes

- Keep commits small and sequential.
- After each completed step, verify the docs build cleanly with:
  `julia -tauto --project=docs docs/make.jl`
- For local docs builds, prefer upstream dependency branches over downgrading
  compat bounds. At the moment the docs environment is configured to use
  `Gabs` from `main` and `QuantumClifford` from `master`.
- If the local workspace manifest drifts behind those compat bounds, refresh it
  against the upstream branches rather than relaxing compat in `Project.toml`.
- Delete this file at the end of the full documentation effort.
