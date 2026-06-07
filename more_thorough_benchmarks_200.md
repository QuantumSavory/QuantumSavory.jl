# File: .agents/channels/classical-and-quantum-channels-user.md
# Channel Internals, Invariants, and Extension Points

Open this file when:

- changing `RegisterNet` channel construction;
- reviewing `MessageBuffer`, forwarding, or `QuantumChannel`;
- debugging transport timing or wakeup behavior;
- extending per-link behavior.

Do not use this file for basic usage examples.
Use `.agents/channels/classical-and-quantum-channels-dev.md` for that.

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
  - an `unlock` with zero waiters is dropped r
---