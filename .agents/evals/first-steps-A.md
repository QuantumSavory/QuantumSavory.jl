Start with the shortest runnable path, then branch by need:

1. Read `docs/src/manual.md` and run the superdense-coding example.
   It gives you `Simulation`, `Register`, symbolic initialization,
   `QuantumChannel`, `@resumable` processes, and `run(sim)` in one compact
   example.
2. Read `docs/src/architecture.md` and `docs/src/why_quantumsavory.md`.
   That gives you the project’s mental model and why the symbolic/frontend,
   backend, register, and protocol layers are separated.
3. For networking-specific work, read these next:
   - `docs/src/discreteeventsimulator.md`
   - `docs/src/metadata_plane.md`
   - `docs/src/tag_query.md`
   - `docs/src/classical_messaging.md`
4. Then move to reusable building blocks:
   - `docs/src/zoos_as_building_blocks.md`
   - `docs/src/API_ProtocolZoo.md`
5. For concrete workflows, use:
   - `docs/src/howto/firstgenrepeater_v2/firstgenrepeater_v2.md`
   - `docs/src/howto/repeatergrid/repeatergrid.md`
   - `docs/src/howto/simpleswitch/simpleswitch.md`

Two caveats:

- `firstgenrepeater_v2` and `simpleswitch` are marked unfinished in the docs,
  but they still point to useful example code in `examples/firstgenrepeater_v2`
  and `examples/simpleswitch`.
- Use the reference pages only after you already know what concept or API you
  are looking for. They are for exact lookup, not first contact.

If you want the fastest “learn by code” path, pair the manual with
`examples/firstgenrepeater_v2/README.md`.

