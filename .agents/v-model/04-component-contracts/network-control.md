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
- **Origin / risk:** Directional-delay and forwarding documentation and implementation;
  high route-selection risk
- **Context:** [Transport](../../context/network/transport.md)

## CMP-008 — Transfer quantum ownership and discard failed delivery

- **Normative statement:** Quantum send shall swap, not copy, the source subsystem into
  in-transit ownership at the channel's current simulation time, apply supported
  background evolution through the arrival time, and on receive swap that ownership
  only into an unassigned destination while retaining every external owner
  backreference of a correlated state. If the destination is assigned, receipt shall
  discard the transmitted state and emit a warning without providing recovery.
- **Parents:** SUB-009
- **Acceptance criterion:** Given a correlated two-subsystem state with one currently
  assigned subsystem whose access time is no later than modeled arrival, when it is
  transmitted through a link with a supported nontrivial background, then the source
  becomes unassigned and exactly one in-transit owner replaces it in the shared
  backreference mapping; when receive occurs at the delayed arrival time into an empty
  destination, then that owner is replaced by the destination, the mapping remains
  bidirectionally consistent, and a joint observable matches stationary evolution
  under the same background for the same interval; when the destination is assigned,
  receipt emits a warning and the in-transit owner and transmitted state are no longer
  available.
- **Verification:** UNITV-007 (test)
- **Origin / risk:** Quantum-channel swap and backreference behavior plus maintainer
  interview; critical no-cloning and state-loss risk
- **Context:** [Transport](../../context/network/transport.md)

## Component limitations

- Quantum multi-hop forwarding is outside this contract.
- Sending from an unassigned source is outside valid modeled use and has no guaranteed
  result.
- Valid models ensure the source local time is no later than modeled arrival.
- Assigned-destination receipt intentionally loses the transmitted state and warns; it
  does not consume work to preserve, requeue, or recover that state.
- Any exception ends the affected run without a post-exception consistency guarantee.
