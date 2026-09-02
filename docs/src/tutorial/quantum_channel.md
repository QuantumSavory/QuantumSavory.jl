# [Send a Qubit Through a Quantum Channel](@id tutorial-quantum-channel)

This tutorial moves one assigned slot across a delayed `QuantumChannel` and
checks that the simulation clock and the destination slot agree with the
channel delay.

The same `put!` / `@yield take!` pattern is used for a network edge obtained
from `qchannel`. Background is in [Quantum Channels](@ref quantum-channels).

## Standalone channel with a delay

Create two registers, initialize Alice's slot, and connect them with a
10-time-unit channel. `put!` does not wait; the receiver must `@yield take!`.

```@example quantum_channel
using QuantumSavory
using ConcurrentSim
using ResumableFunctions

sim = Simulation()
regA = Register(1)
regB = Register(1)
initialize!(regA[1], Z1)
qc = QuantumChannel(sim, 10.0)

@resumable function alice_node(env, qc)
    put!(qc, regA[1])
end

@resumable function bob_node(env, qc)
    @yield take!(qc, regB[1])
end

@process alice_node(sim, qc)
@process bob_node(sim, qc)
run(sim)

now(sim), isassigned(regA, 1), isassigned(regB, 1)
```

The clock is 10, Alice's slot is empty, and Bob holds the qubit. That is the
whole contract of a standalone quantum channel: delayed swap of one slot.

## In-transit noise is a constructor argument

Pass a background as the third argument when the traveling slot should decay
while it is in the channel. The tests compare this against a stationary qubit
that spent the same time under the same background.

```julia
qc = QuantumChannel(sim, 10.0, T1Decay(0.1))
```

Network-attached channels currently do not take a background. Their delay
comes only from `RegisterNet(...; quantum_delay=...)`.

## Direct network edges, not a path

`qchannel(net, src => dst)` is the same `put!`/`take!` object, keyed by a
directed graph edge. On a 3-node chain, `1 => 2` exists and `1 => 3` does not.

```@example quantum_channel_net
using QuantumSavory
using ConcurrentSim
using ResumableFunctions

net = RegisterNet([Register(1), Register(1), Register(1)]; quantum_delay=5.0)
initialize!(net[1, 1], Z1)
qc = qchannel(net, 1 => 2)
sim = get_time_tracker(net)

@resumable function send(env, qc)
    put!(qc, net[1, 1])
end

@resumable function recv(env, qc)
    @yield take!(qc, net[2, 1])
end

@process send(sim, qc)
@process recv(sim, qc)
run(sim)

now(sim), isassigned(net[1], 1), isassigned(net[2], 1)
```

`qchannel(net, 1 => 3)` errors because there is no direct quantum edge. There
is no `permit_forward` for qubits. Hop-by-hop entanglement is a protocol
(entangler plus swapper), not a channel feature.

## Carry forward

- `put!` moves an assigned slot; `take!` must be yielded and needs an empty
  destination.
- Delay is simulation time. In-transit noise is only on the standalone
  constructor today.
- For classical control messages, including optional forwarding, use
  [Classical Messaging and Buffers](@ref classical-messaging).
