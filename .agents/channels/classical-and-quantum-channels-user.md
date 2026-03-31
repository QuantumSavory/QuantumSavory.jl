# Using Classical Messaging and Quantum Channels

Open this file when:

- you need classical control traffic between nodes;
- you need to receive messages through a node buffer;
- you need to move a quantum subsystem through a delayed channel.

Do not use this file for:

- `MessageBuffer` wakeup internals;
- forwarding implementation details;
- review of channel invariants.

Use `.agents/channels/classical-and-quantum-channels-dev.md` for those.

## Mental Model

- QuantumSavory has two transport planes:
  - classical control traffic through `channel(...)` and `messagebuffer(...)`;
  - quantum transport through `QuantumChannel(...)` or `qchannel(...)`.
- Classical traffic carries `Tag`s.
- Quantum traffic moves one assigned register slot, including its entanglement, through a delayed transport step.

## Classical Messaging

Direct classical send:

```julia
put!(channel(net, 1 => 2), Tag(:swap_request))
msg = querydelete!(messagebuffer(net, 2), :swap_request)
```

Multihop classical forwarding:

```julia
put!(channel(net, 1 => 4; permit_forward=true), Tag(:swap_request))
```

Useful rule:

- send on a channel when network delay matters;
- consume from the destination message buffer;
- use local `put!(messagebuffer(...), tag)` or `put!(net[node], tag)` only for intentional local injection.

## Quantum Transport

Standalone quantum channel:

```julia
qc = QuantumChannel(sim, 10.0)
put!(qc, regA[1])
@yield take!(qc, regB[1])
```

Network-attached quantum channel:

```julia
put!(qchannel(net, 1 => 2), net[1, 1])
@yield take!(qchannel(net, 1 => 2), net[2, 1])
```

## Public APIs To Prefer

- Classical:
  - `channel(net, src => dst; permit_forward=false)`
  - `messagebuffer(net, dst)`
  - `messagebuffer(reg)`
  - `put!`
  - `query`
  - `querydelete!`
  - `querydelete_wait!`
- Quantum:
  - `QuantumChannel(sim, delay, background=nothing, trait=Qubit())`
  - `qchannel(net, src => dst)`
  - `put!`
  - `take!`

## Usage Guidance

- Message buffers are the normal receive side for classical protocols.
- `permit_forward=true` affects only classical traffic.
- `qchannel(net, ...)` is a direct-edge quantum link, not an automatic repeater or routing layer.
- The destination slot for `take!` on a quantum channel must be empty.
- If in-transit noise matters, construct the `QuantumChannel` with a background process.

## Good Docs And Examples To Open Next

- `docs/src/manual.md`
- `docs/src/classical_messaging.md`
- `docs/src/discreteeventsimulator.md`
- `docs/src/howto/firstgenrepeater/firstgenrepeater.md`
- `docs/src/howto/firstgenrepeater_v2/firstgenrepeater_v2.md`
- `../writeup/Tags.tex`
- `../writeup/qtcp.tex`

## Common Mistakes

- Sending to a non-neighbor classical node without `permit_forward=true`.
- Assuming classical forwarding implies any quantum multihop support.
- Receiving quantum traffic into an already assigned slot.
- Bypassing the message buffer when the goal is decoupled protocol composition.
