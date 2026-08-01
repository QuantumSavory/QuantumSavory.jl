# Transport

- **Context need:** Reference
- **Open when:** Checking network construction, directional delays, classical forwarding, or quantum handoff behavior.
- **Do not open when:** Developing protocol race logic, changing backend evolution, or browsing zoo catalogs.
- **Review when:** `RegisterNet`, classical channels, message buffers, quantum channels, or delay configuration changes.

## Current transport boundaries

A `RegisterNet` binds a graph and its node registers to one ConcurrentSim simulation.
Classical and quantum edge delays may be constants or direction-aware callables. Delay
is scheduled in the network simulation; it is not wall-clock waiting.

Construction uses the first register's simulation. All registers must already use that
same simulation, or every register simulation must be unused at time zero (zero `now`,
empty event heap, and no active process). In the latter case, construction rehomes each
register's slot locks and tag notifier to the first simulation. A nonzero or scheduled
independent register is rejected.

Classical messages have two modes. Direct delivery sends to an adjacent destination
buffer. Forwarded delivery follows the graph toward a non-adjacent node and incurs the
configured directional delays. Message buffers maintain their own tag indexes and
arrival notifications. Selection follows insertion-order identifiers (FIFO), unlike
the register query default of FILO.

Quantum transport is direct-edge only. It is keyed by source/destination channel and
does not inherit classical multi-hop forwarding. A standalone `QuantumChannel` owns a
temporary one-slot register with the channel's configured background: `put!` swaps
ownership into that slot at channel time and applies in-transit background evolution to
the modeled arrival time before queueing.

The temporary register uses the channel trait and that trait's default representation,
but `swap!` moves state ownership without reconciling the source, channel, or
destination representation declarations. RegisterNet edge channels also currently
default to `Qubit`. Transport does not validate trait compatibility. It also lacks the
intended automatic common-representation promotion and performance warning.

The source/channel time relationship must be valid before transport. Today, if a source
slot's local access time is later than the modeled arrival, `put!` can throw only after
ownership has moved out of the source. Receiving likewise dequeues the in-flight item
before checking whether the destination is occupied. An occupied-destination exception
therefore loses the transmitted state. The intended warning for that loss is not
implemented. No recovery or post-exception consistency is promised; abandon the run.
`put!` does not reject an empty source; it queues an empty channel register.

Construction is the validation boundary for register count and simulation-domain
compatibility. The simulation-domain path validates before rehoming registers, but the
graph/register size path merely constructs an `ArgumentError` without throwing it.
`add_register!` is an internal incomplete path: it updates only the graph and register
vector and computes an invalid return value. Reconstruct the network instead.

The graph provides channels and physical-topology metadata, but locality is not a
general register-operation guard: code can directly operate on slots from arbitrary
registers, and only selected protocol constructors validate adjacency. Treat physical
locality as a protocol/model responsibility unless the chosen API explicitly enforces
it.

Transport moves ownership; it does not clone quantum state. Metadata describing an
entangled counterpart must be forwarded and revalidated separately from the physical
state handoff.

## Anchors

- **Source:** [`src/networks.jl`](../../../src/networks.jl), [`src/messagebuffer.jl`](../../../src/messagebuffer.jl), and [`src/quantumchannel.jl`](../../../src/quantumchannel.jl) — network, classical, and quantum transport.
- **Docs:** [`docs/src/classical_messaging.md`](../../../docs/src/classical_messaging.md) and [`docs/src/architecture.md`](../../../docs/src/architecture.md) — human messaging and architecture model.
- **Test:** [`test/general/registernet_interface_tests.jl`](../../../test/general/registernet_interface_tests.jl), [`test/general/messagebuffer_tests.jl`](../../../test/general/messagebuffer_tests.jl), and [`test/general/quantumchannel_tests.jl`](../../../test/general/quantumchannel_tests.jl) — exercised construction and delivery behavior.

## Known gaps

- Occupied quantum receipt loses the state but emits no warning.
- Graph/register count mismatch is not rejected because the constructed
  `ArgumentError` is not thrown.
- `add_register!` cannot update a complete network.
- Empty-source quantum send is not validated.
- Quantum send/receive does not validate trait compatibility or reconcile declared
  representations; RegisterNet-created quantum channels are always qubit channels.

Quantum channels remain direct primitives; only classical transport currently has
explicit multi-hop forwarding.
