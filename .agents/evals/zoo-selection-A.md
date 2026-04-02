They do live at different layers.

Use `StatesZoo` when you need a reusable parameterized resource state.

- Example use: initialize a register from `BarrettKokBellPair(...)`.
- Think of it as a catalog of state families, not a full control-flow system.

Use `CircuitZoo` when you need reusable local quantum logic that acts
immediately on chosen slots.

- Example use: entanglement swapping, purification, fusion, or superdense-code
  encode/decode routines.
- Circuits do not own waiting, retries, or message handling.
- If you need only local quantum work, this is usually the right layer.

Use `ProtocolZoo` when you need long-running control-plane components.

- Example use: entanglers, swappers, trackers, cutoff logic, switch
  controllers, or the QTCP stack.
- These are scheduled as processes with `@process prot()`.
- They compose through tags and message buffers rather than hard-wired calls.

The simplest rule is:

- state family -> `StatesZoo`
- local reusable circuit -> `CircuitZoo`
- time-dependent protocol component -> `ProtocolZoo`

One extra caveat: if you need scheduling, resource discovery, or retries, use
`ProtocolZoo`, not `CircuitZoo`.
