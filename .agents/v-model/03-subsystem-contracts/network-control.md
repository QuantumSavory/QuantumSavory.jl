# Network and Transport Contracts

## SUB-007 — Construct one network scheduling domain with directional delays

- **Normative statement:** The network-construction boundary shall associate every
  included register, channel, and incoming message store with one simulation scheduling
  domain, preserve the declared topology, and resolve classical and quantum delay
  values independently for each directed edge.
- **Parents:** SYS-006
- **Acceptance criterion:** Given an undirected three-location topology, initially
  unused registers, and delay functions that return a distinct value for every ordered
  endpoint pair, when the network is constructed, then all included resources share
  one simulation clock, every undirected edge exposes both directed channel pairs, each
  channel records the value for its own direction, and every location has one incoming
  message store. A register/location count mismatch and a register already used in an
  incompatible scheduling domain each report failure rather than producing a usable
  network.
- **Verification:** INTV-004 (test)
- **Origin / risk:** Network construction and directional-delay behavior; maintainer
  confirmation pending; high scheduling-domain risk
- **Context:** [Transport](../../context/network/transport.md)

### Boundary semantics

- **Inputs:** A topology, one register per location, scalar or direction-dependent
  classical and quantum delays, and optional network metadata.
- **Outputs:** A network whose locations, directed channels, incoming stores, and
  register membership are mutually addressable.
- **State:** Initially unused registers may join the common scheduling domain; registers
  already used in incompatible domains are not silently rehomed.
- **Errors:** Construction shall reject a register/location count mismatch. The current
  constructor only creates an `ArgumentError` value and continues, so it is
  nonconforming. Incompatible used scheduling domains report failure. Dynamic network
  mutation is not specified.

## SUB-008 — Separate direct and forwarded classical transport

- **Normative statement:** The classical transport boundary shall deliver direct-link
  messages after the configured directional delay, aggregate arrived messages by
  destination, reject a nonexistent direct-link request by default, and perform
  shortest-path forwarding only when the sender explicitly permits forwarding.
- **Parents:** SYS-006
- **Acceptance criterion:** Given a topology with asymmetric direct delays and
  distinguishable shorter and longer multi-hop alternatives, when a direct message is
  sent in each direction, then each reaches only the destination incoming store after
  the delay applicable to its traversed direct link; when an endpoint-to-endpoint
  message is sent without forwarding it reports no direct link, and when the same
  message is sent with forwarding it reaches the final destination over the shortest
  declared path and retains its payload.
- **Verification:** INTV-004 (test)
- **Origin / risk:** Classical channel and forwarding behavior; maintainer confirmation
  pending; high routing risk
- **Context:** [Transport](../../context/network/transport.md)

### Boundary semantics

- **Inputs:** Source, destination, supported message value, and explicit forwarding
  permission.
- **Outputs:** A direct channel handle, an explicit forwarder, delivered destination
  message entry, or no-direct-link failure.
- **State:** Intermediate forwarding changes only transport envelopes; the final
  incoming store receives the original message payload and its immediate arrival
  source metadata.
- **Errors:** Missing direct connectivity reports failure unless forwarding is
  explicitly permitted. Unreachable destinations and forwarding-loop policy are not
  separately specified.

## SUB-009 — Move quantum ownership over direct delayed links

- **Normative statement:** The quantum transport boundary shall move an assigned source
  subsystem's logical ownership into a direct channel, advance it through configured
  delay and supported channel background evolution, and move it into an empty
  destination while preserving correlations with subsystems that did not enter the
  channel.
- **Parents:** SYS-006
- **Acceptance criterion:** Given one half of a correlated two-subsystem state at a
  currently assigned source, the retained half elsewhere, a source access time no later
  than modeled arrival, a direct quantum link with nonzero delay and a supported
  background, and an empty destination, when send and receive complete, then the source
  is unassigned immediately after send, the destination remains unchanged before
  arrival, the destination owns the transmitted subsystem at arrival, and a joint
  observable with the retained half matches a stationary subsystem evolved under the
  same background for the same interval; receiving into an assigned destination
  reports failure.
- **Verification:** INTV-004 (test)
- **Origin / risk:** Quantum-channel state-transfer behavior; maintainer confirmation
  pending; high state-loss risk
- **Context:** [Transport](../../context/network/transport.md)

### Boundary semantics

- **Inputs:** A direct quantum link, source slot, destination slot, delay, and optional
  supported channel background.
- **Outputs:** Source unassignment, an in-transit logical subsystem, and destination
  assignment after receive.
- **State:** Ownership moves; the quantum state is not copied. Backreferences preserving
  correlations outside the channel remain valid.
- **Errors:** Receiving into an assigned destination reports failure. Multi-hop quantum
  routing and the behavior of sending an unassigned source are not specified.

## SUB-016 — Preserve topology access and metadata addressing

- **Normative statement:** The network access boundary shall expose its declared graph,
  registers, and logical slots through indexed and graph-compatible queries; preserve
  one metadata namespace per vertex, one endpoint-order-invariant namespace per
  undirected edge, and separate namespaces per directed edge; and apply bulk metadata
  operations to the existing addressed collection.
- **Parents:** SYS-013
- **Acceptance criterion:** Given a network with multiple vertices and edges, indexed
  access returns the intended register and slot and graph queries return the declared
  topology; vertex metadata round-trips only at its vertex, tuple or graph-edge lookup
  returns the same undirected value in either endpoint order, opposing pair directions
  retain unequal values, and scalar and function-valued bulk assignment produce one
  retrievable value for every existing addressed vertex or edge.
- **Verification:** INTV-009 (test)
- **Context:** [Network topology and metadata](../../context/network/topology-and-metadata.md)

### Boundary semantics

- **Inputs:** A vertex, undirected edge, directed edge, register/slot index, graph
  query, or bulk collection selector plus an optional metadata key and value factory.
- **Outputs:** Graph structure, register/slot references, or addressed metadata values.
- **State:** Metadata changes do not change topology, transport, register ownership, or
  simulated time.
- **Errors:** Missing metadata keys follow mapping lookup behavior. Dynamic topology
  growth is not part of this static-network contract.
