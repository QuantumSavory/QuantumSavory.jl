# Network and Transport Component Contracts

## CMP-007 — Resolve delays per direction and require explicit classical forwarding

- **Normative statement:** Network construction shall resolve scalar or callable delay
  configuration independently for both directions of every declared edge; a classical
  send shall use only its direct directed channel unless forwarding is explicitly
  requested, in which case each hop shall recompute or select the next edge toward the
  final destination without changing the inner message.
- **Parents:** SUB-007, SUB-008
- **Acceptance criterion:** Given an edge whose delay function returns unequal values
  for `A→B` and `B→A` and a three-location path, when direct messages traverse both
  directions, then their arrival times differ according to those values; when `A→C` is
  requested without forwarding it reports no direct channel, and when requested with
  forwarding the message reaches `C`, traverses only declared path edges, and has the
  same inner tag shape and values at final arrival.
- **Verification:** UNITV-006 (test)
- **Origin / risk:** Directional-delay and forwarding behavior; maintainer confirmation
  pending; high route-selection risk
- **Context:** [Transport](../../context/network/transport.md)

## CMP-008 — Transfer quantum ownership only into an empty destination

- **Normative statement:** Quantum send shall swap, not copy, the source subsystem into
  in-transit ownership at the channel's current simulation time, apply supported
  background evolution through the arrival time, and on receive swap that ownership
  only into an unassigned destination while retaining every external owner
  backreference of a correlated state.
- **Parents:** SUB-009
- **Acceptance criterion:** Given a correlated two-subsystem state with one currently
  assigned subsystem whose access time is no later than modeled arrival, when it is
  transmitted through a link with a supported nontrivial background, then the source
  becomes unassigned and exactly one in-transit owner replaces it in the shared
  backreference mapping; when receive occurs at the delayed arrival time into an empty
  destination, then that owner is replaced by the destination, the mapping remains
  bidirectionally consistent, and a joint observable matches stationary evolution
  under the same background for the same interval; when the destination is assigned,
  receive reports failure rather than overwriting it.
- **Verification:** UNITV-007 (test)
- **Origin / risk:** Quantum-channel swap and backreference behavior; maintainer
  confirmation pending; critical no-cloning and state-loss risk
- **Context:** [Transport](../../context/network/transport.md)

## Component limitations

- Quantum multi-hop forwarding is outside this contract.
- Sending an unassigned source is unresolved and therefore has no normative result.
- A source access time later than the modeled arrival can currently cause a rewind
  failure after ownership has moved into the channel; rollback is unresolved.
- Receiving failure is not stated to consume, requeue, or roll back an in-transit
  subsystem; that recovery policy requires maintainer confirmation.
