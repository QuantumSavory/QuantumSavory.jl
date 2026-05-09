QuantumSavory models channels through two separate transport planes.

Classical transport:

- `channel(net, src => dst)` gives a classical link on a `RegisterNet`;
- messages are `Tag`s;
- `RegisterNet(...; classical_delay=Δt)` makes classical latency part of the
  simulation clock;
- multihop forwarding is available for classical traffic with
  `permit_forward=true`.

Quantum transport:

- `QuantumChannel(sim, delay)` gives a standalone delayed quantum channel;
- `qchannel(net, src => dst)` gives a network-attached direct-edge quantum
  channel;
- the channel moves one assigned slot, including its entanglement, through a
  delayed transport step.

For time dependence and noise, the docs distinguish two cases:

- long-lived background processes belong on register slots, where they are
  declared once and applied on demand as time advances;
- if in-transit noise matters on a standalone quantum channel, construct the
  `QuantumChannel` with a background process.

The package documentation is strongest on delay, background noise, and
discrete-event timing. It does not describe an all-in-one automatic channel
model that simultaneously handles routing, loss, and repeater behavior for
quantum traffic. In particular, `qchannel(net, ...)` is a direct-edge link, not
an automatic multihop repeater layer.

So the practical answer is:

- delay is explicit;
- noise is modeled declaratively through backgrounds and backend lowering;
- classical forwarding exists;
- quantum multihop transport is built at the protocol layer, not the channel
  primitive.

