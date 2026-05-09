Start with the shortest runnable path, then branch by need:

1. Read the Manual and run the superdense-coding example.
   It gives you `Simulation`, `Register`, symbolic initialization,
   `QuantumChannel`, `@resumable` processes, and `run(sim)` in one compact
   example.
2. Read "Architecture and Mental Model" and "Why QuantumSavory Exists".
   That gives you the project’s mental model and why the symbolic/frontend,
   backend, register, and protocol layers are separated.
3. For networking-specific work, read these next:
   - "Discrete Event Simulator"
   - "Metadata and Protocol Composition"
   - "Tagging and Querying"
   - "Classical Messaging and Buffers"
4. Then move to reusable building blocks:
   - "Zoos as Composable Building Blocks"
   - "Predefined Networking Protocols"
5. For concrete workflows, use:
   - the simpler first-generation repeater how-to
   - the repeater grid how-to
   - the entanglement switch how-to

Two caveats:

- `firstgenrepeater_v2` and `simpleswitch` are marked unfinished in the docs,
  but they still point to useful bundled examples.
- Use the reference pages only after you already know what concept or API you
  are looking for. They are for exact lookup, not first contact.

If you want the fastest “learn by code” path, pair the manual with the simpler
first-generation repeater example.
