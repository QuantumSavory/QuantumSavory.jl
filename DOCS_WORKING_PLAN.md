# QuantumSavory.jl Documentation Working Plan

Temporary working file for the docs-improvement PR series.
Delete this file at the end of the overall documentation effort.

Branch: `docs-paper-alignment-codex`

## Planned Steps

- [x] 1. Turn the Explanation, Tutorial, and Reference landing pages into real hubs with reading order and scope.
- [x] 2. Split homepage vs onboarding tutorial: keep `index.md` short and directional, and make `manual.md` the first real tutorial.
- [x] 3. Add a new "Architecture and Mental Model" explanation page as the main entry point for understanding the library.
- [x] 4. Split conceptual material from API material so Explanation stops carrying disguised reference docs.
- [x] 5. Add a "Choosing a Backend / Modeling Tradeoffs" explanation page.
- [ ] 6. Move `Figs/qsavory.png` into the new architecture page and probably the homepage.
- [ ] 7. Move `Figs/overview_ex.png` into the new introductory tutorial / walkthrough.
- [ ] 8. Move `Figs/models.png` into the backend/modeling-tradeoffs explanation.
- [ ] 9. Move `Figs/bkslider.png` into the StateZoo / state explorer docs.
- [ ] 10. Move `Figs/showmethod.png` into the ProtocolZoo / visualization docs.
- [ ] 11. Move `Figs/two-way.pdf` and `Figs/one-way.pdf` into a quantum-networking background explanation.
- [ ] 12. Move `Figs/distillation.pdf` and `Figs/correction.pdf` into that same networking background page.
- [ ] 13. Decide whether `Figs/compare.png` belongs in a durable "Why QuantumSavory" page.
- [ ] 14. Rewrite the landing-page language from the paper's introduction: codesign, digital twins, symbolic frontend, interchangeable backends.
- [ ] 15. Add a "Why QuantumSavory Exists" explanation page from the related-work section.
- [ ] 16. Add a background explanation page on quantum systems: open systems, subsystem types, entanglement, and why this matters for QSavory.
- [ ] 17. Add a background explanation page on restricted formalisms: stabilizer, Gaussian, tensor-network, finite-rank / near-Clifford methods.
- [ ] 18. Add a background explanation page on networking design axes: one-way vs two-way, distillation vs error correction.
- [ ] 19. Turn the cluster-state overview into a real tutorial.
- [ ] 20. Add a modeling explanation page focused on register composition, factorization, lazy evolution, and declarative noise.
- [ ] 21. Expand the slot-properties docs so they explain heterogeneous subsystems instead of only listing types.
- [ ] 22. Expand the background-noise docs so they explain the declarative model and lazy-time semantics.
- [ ] 23. Split symbolic docs into a conceptual "symbolic frontend" explanation plus retained examples/reference.
- [ ] 24. Expand backend docs to cover `QuantumClifford`, `QuantumOptics`, `Gabs`, extension points, and when to choose each.
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
- Delete this file at the end of the full documentation effort.
