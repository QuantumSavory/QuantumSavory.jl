# Channel Internals, Invariants, and Extension Points

Open this file when:

- changing `RegisterNet` channel construction;
- reviewing `MessageBuffer`, forwarding, or `QuantumChannel`;
- debugging transport timing or wakeup behavior;
- extending per-link behavior.

Do not use this file for basic usage examples.
Use `.agents/channels/classical-and-quantum-channels-user.md` for that.

## Classical Side

- `RegisterNet` materializes directed classical channels for every undirected edge.
- Each `MessageBuffer` is backed by one `take_loop_mb` process per incoming edge.
- Forwarding is implemented by `ChannelForwarder` plus the internal `Forward` tag variant.
- Forwarded messages recompute the shortest path at each hop.
- `Base.put!(reg::Register, tag)` delegates to `messagebuffer(reg)` and is an intentional local injection path.

## MessageBuffer Invariants

- `tag_waiter` is edge-triggered:
  - it wakes tasks that are already blocked in `onchange(mb)` or `wait(mb)`.
- `no_wait` stores one queued wakeup per arrival that happened while nobody was
  waiting.
- `no_wait` is required because `AsymmetricSemaphore` is not a counting
  semaphore:
  - an `unlock` with zero waiters is dropped rather than remembered for a later
    waiter.
- This is intentionally different from register tag waiting:
  - register `onchange(reg, Tag)` is future-edge waiting only;
  - `MessageBuffer` preserves the older contract that a later `onchange(mb)`
    wakes immediately once per already-buffered arrival.
- Buffer entries are stored as `(; src, tag)` in arrival order.
- `tag!(::MessageBuffer, ...)` is deliberately rejected.
- `onchange(mb, Tag)` is not more selective than `onchange(mb)` today.
- If code already knows the predicate it wants, prefer `query_wait` or
  `querydelete_wait!` over `onchange(...)` followed by a query:
  - the helpers query first and then wait, so they behave consistently on both
    `Register` and `MessageBuffer`.

## Quantum Side

- `QuantumChannel.put!`:
  - builds a temporary single-slot register,
  - `swap!`s the source slot into it,
  - advances that slot to arrival time with `uptotime!`,
  - enqueues the temporary register
- `QuantumChannel.take!` returns a process that waits for arrival and then swaps into the destination slot.
- Runtime error is expected if the destination slot is already assigned.
- Network `qchannel(net, ...)` currently gives direct-edge channels with default trait/background choices unless you replace them yourself.

## Review Checks

- Preserve `MessageBuffer` wakeup behavior whenever touching wait logic.
- Check both MessageBuffer wait paths:
  - message arrives while a task is already blocked;
  - message arrives before any later `onchange(mb)` call.
- Do not simplify `MessageBuffer` waiting to a pure semaphore without also
  changing callers and tests.
- Prefer `query_wait` or `querydelete_wait!` in protocol code when the awaited
  condition is already known.
- Keep direct-edge versus forwarded classical paths clearly separate.
- Check for accidental language in docs or code reviews that implies enforced locality. The framework models locality; it does not enforce it at the Julia level.
- Watch for hidden timing assumptions between:
  - local buffer injection
  - direct channel send
  - forwarded classical send
- For quantum transport, confirm entanglement movement is still correct when source slots were part of larger shared states.

## Source Files To Read

- `src/networks.jl`
- `src/messagebuffer.jl`
- `src/quantumchannel.jl`
- `src/ProtocolZoo/qtcp.jl`
- `src/ProtocolZoo/swapping.jl`
- `src/ProtocolZoo/cutoff.jl`

## Tests To Anchor Behavior

- `test/general/messagebuffer_tests.jl`
- `test/general/quantumchannel_tests.jl`
- `test/general/protocolzoo_qtcp_tests.jl`

## Public Docs And Paper To Cross-Check

- `docs/src/classical_messaging.md`
- `docs/src/manual.md`
- `docs/src/discreteeventsimulator.md`
