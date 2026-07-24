# Network and Control System Requirements

## SYS-006 — Transport delayed classical messages and quantum state

- **Normative statement:** The product shall provide directional delayed classical
  transport, explicit direct-versus-forwarded classical routing, per-location incoming
  message stores, and direct-link quantum transport that moves logical state ownership
  after configured delay and supported in-transit evolution.
- **Parents:** STK-001, STK-003
- **Acceptance criterion:** Given a three-location path with directional delays, direct
  classical and quantum deliveries arrive no earlier than their configured delays; a
  nonadjacent classical request reports no direct channel without forwarding and
  reaches the final incoming store with forwarding; quantum ownership moves to an
  empty destination without breaking a retained remote correlation; and a transmitted
  subsystem under a supported nontrivial channel background has the same joint
  observable as stationary evolution under that background for the same interval.
- **Verification:** SYSV-004 (test)
- **Context:** [Transport](../../context/network/transport.md)

## SYS-013 — Inspect register and network structure and metadata

- **Normative statement:** The product shall expose nonmutating inspection of register
  assignment and numerical state plus indexed access to network registers, slots, and
  topology, and shall store and retrieve user metadata independently for vertices,
  undirected edges, and directed edges.
- **Parents:** STK-005
- **Acceptance criterion:** Given a network with multiple registers, an assigned shared
  state, vertex and undirected-edge metadata, and unequal metadata for opposing directed
  edges, public inspection reports assignment, shared ownership, and native state
  without mutation; graph and indexed queries reproduce the declared topology,
  registers, and slots; metadata values round-trip; undirected lookup is invariant to
  endpoint order while opposing directed values remain distinct; and bulk access or
  assignment covers the existing vertex or edge collection.
- **Verification:** SYSV-010 (test)
- **Context:** [Register model](../../context/core/register-model.md) and
  [network topology and metadata](../../context/network/topology-and-metadata.md)
