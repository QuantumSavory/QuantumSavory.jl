# Transport

- **Context need:** Reference
- **Open when:** Checking network construction, directional delays, classical forwarding, or quantum handoff behavior.
- **Do not open when:** Developing protocol race logic, changing backend evolution, or browsing zoo catalogs.
- **Related specification IDs:** SYS-006, SUB-007, SUB-008, SUB-009, CMP-007, CMP-008
- **Review when:** `RegisterNet`, classical channels, message buffers, quantum channels, or delay configuration changes.

## Current transport boundaries

A `RegisterNet` binds a graph and its node registers to one SimJulia simulation.
Classical and quantum edge delays may be constants or direction-aware callables. Delay
is scheduled in the network simulation; it is not wall-clock waiting.

Classical messages have two modes. Direct delivery sends to an adjacent destination
buffer. Forwarded delivery follows the graph toward a non-adjacent node and incurs the
configured directional delays. Message buffers maintain their own tag indexes and
arrival notifications. Selection follows insertion-order identifiers (FIFO), unlike
the register query default of FILO.

Quantum transport is direct-edge only. It is keyed by source/destination channel and
does not inherit classical multi-hop forwarding. Sending swaps the quantum state from
the source into channel-owned temporary storage before queueing it. If the source access
time is already later than the channel clock plus its delay, that swap can advance the
temporary slot and the subsequent arrival-time advance can throw a rewind error after
the source is empty. Receiving likewise dequeues the in-flight item before checking
whether the destination is occupied. Neither failure path has a specified rollback.
Sending from an empty source is also unresolved. Protocols should validate source
occupancy, destination vacancy, time consistency, and direct connectivity while still
handling interleaving failures.

Two `RegisterNet` construction paths are defective. The constructor creates an
`ArgumentError` for graph/register size mismatch but does not throw it, and
`add_register!` updates only part of the network and computes an invalid return value.
Do not rely on dynamic node insertion or mismatch rejection until those paths are fixed
and tested.

Transport moves ownership; it does not clone quantum state. Metadata describing an
entangled counterpart must be forwarded and revalidated separately from the physical
state handoff.

## Anchors

- **Source:** [`src/networks.jl`](../../../src/networks.jl), [`src/messagebuffer.jl`](../../../src/messagebuffer.jl), and [`src/quantumchannel.jl`](../../../src/quantumchannel.jl) — network, classical, and quantum transport.
- **Docs:** [`docs/src/classical_messaging.md`](../../../docs/src/classical_messaging.md) and [`docs/src/architecture.md`](../../../docs/src/architecture.md) — human messaging and architecture model.
- **Test:** [`test/general/registernet_interface_tests.jl`](../../../test/general/registernet_interface_tests.jl), [`test/general/messagebuffer_tests.jl`](../../../test/general/messagebuffer_tests.jl), and [`test/general/quantumchannel_tests.jl`](../../../test/general/quantumchannel_tests.jl) — exercised construction and delivery behavior.

## Unresolved questions

- What recovery guarantee should follow an occupied-destination quantum receive?
- Should quantum channels gain explicit multi-hop forwarding, or remain direct primitives?
- What are the intended `add_register!` updates and return value?
