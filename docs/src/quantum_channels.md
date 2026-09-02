# [Quantum Channels](@id quantum-channels)

QuantumSavory has a second transport plane next to classical tags and message
buffers: a `QuantumChannel` moves an assigned register slot, including any
entanglement it already has, across a delayed link.

## Two Ways To Get A Channel

A standalone channel is a delayed queue on a `ConcurrentSim` environment:

```julia
sim = Simulation()
qc = QuantumChannel(sim, 10.0)                 # delay 10, no in-transit noise
qc = QuantumChannel(sim, 10.0, T1Decay(0.1))   # same delay, T1 during transit
```

The optional third argument is a background process applied to the traveling
slot. The optional fourth argument is the slot trait and defaults to `Qubit()`.

A network-attached channel is a direct edge of a [`RegisterNet`](@ref):

```julia
net = RegisterNet([Register(1), Register(1)]; quantum_delay=5.0)
qc = qchannel(net, 1 => 2)
qc === qchannel(net, net[1] => net[2])
```

`RegisterNet` builds one `QuantumChannel` per directed graph edge at
construction time. The `quantum_delay` keyword (a number or a `(src, dst) ->
delay` callable) is the only noise/timing parameter that constructor currently
forwards. Network-attached channels have no in-transit background; if transit
noise matters, use a standalone `QuantumChannel`.

## `put!` Sends, `take!` Receives

The payload is a [`RegRef`](@ref), not a [`Tag`](@ref).

```julia
put!(qc, source_slot)
@yield take!(qc, dest_slot)
```

`put!` does not wait. It immediately swaps the source slot into a temporary
one-slot register owned by the channel (the source is empty from that moment),
applies the configured delay and any background with `uptotime!`, and enqueues
that register.

`take!` *does* wait. It returns a simulation process; protocol code must
`@yield` it. After the delay, the traveling slot is swapped into `dest_slot`.

The destination slot must be empty. Taking into an already-initialized slot
throws:

```text
A take! operation is being performed on a QuantumChannel in order to swap
the state into a Register, but the target register slot is not empty
(it is already initialized).
```

There is no quantum analogue of [`messagebuffer`](@ref). Each `QuantumChannel`
is a single directed pipe. The receiver names the destination slot.

A process that `put!`s without a matching `take!` leaves the state sitting in
the channel's delay queue. Dropping unclaimed states is [not implemented
yet](https://github.com/QuantumSavory/QuantumSavory.jl/issues/54).

## Direct Edges Only

`qchannel(net, src => dst)` looks up the directed edge created with the
network. It does not search for a path, and it has no `permit_forward`
keyword.

```julia
net = RegisterNet([Register(1), Register(1), Register(1)])  # a 3-node chain
qchannel(net, 1 => 2)  # ok, adjacent
qchannel(net, 1 => 3)  # error: no direct quantum channel
```

Classical forwarding with `channel(net, src => dst; permit_forward=true)` is
unrelated: it wraps a `Tag` and re-emits it hop by hop. That is not a repeater
layer, and it does not move qubits.

End-to-end quantum connectivity across several hops is built at the protocol
layer, typically with `EntanglerProt`, `SwapperProt`, and `EntanglementTracker`.
See [Zoos as Composable Building Blocks](@ref zoos-building-blocks) and the
[1st-gen Repeater](howto/firstgenrepeater/firstgenrepeater.md) how-to.

## Entanglement Travels With The Slot

`put!` moves the slot's current assignment. If that slot is half of an
entangled pair, the pair stays entangled; only the physical location of one
half changes, after the configured delay.

A Bell pair with one half sent through a T1 or T2 channel matches a stationary
pair that experienced the same background for the same duration.

## Delay And Noise Are Separate Knobs

| Knob | What it models | Where it is set |
|:--|:--|:--|
| `quantum_delay` / `QuantumChannel` delay | How long the slot is in transit on the simulation clock | `RegisterNet(...; quantum_delay=...)` or `QuantumChannel(sim, delay)` |
| Channel background | Noise applied to the traveling slot during that delay | Third argument of the standalone `QuantumChannel` constructor |
| Register-slot background | Noise on a stored qubit while it sits in a node | `Register([...], [T1Decay(...), ...])` |

The delay advances simulation time. It is not wall-clock sleep. The same
discrete-event clock drives [`channel`](@ref) delays, so heralding messages and
flying qubits can be given different latencies on purpose.

## Why This Is A Separate Plane From Classical Messaging

| | Classical | Quantum |
|:--|:--|:--|
| Handle | `channel(net, src => dst)` | `qchannel(net, src => dst)` or `QuantumChannel(sim, delay)` |
| Payload | `Tag` | assigned `RegRef` |
| Receive | usually `messagebuffer(net, dst)` | `take!(qc, dest_slot)` into an empty slot |
| Multihop | `permit_forward=true` | not available |
| Typical use | swap requests, entanglement updates, other control | moving a physical qubit assignment across a direct link |

Keep the two planes distinct. Control traffic belongs on tags and buffers.
Physical qubit motion belongs on `QuantumChannel`. Repeater-style end-to-end
entanglement is a protocol, not a channel feature.

## Where To Go Next

- Read [Classical Messaging and Buffers](@ref classical-messaging) for the
  control-traffic counterpart, including `permit_forward`.
- Read [Register Networks](@ref register-networks) for `quantum_delay` and
  network construction.
- Read [Discrete Event Simulator](@ref sim) for `@resumable` / `@yield`
  around `take!`.
- Work through [Send a Qubit Through a Quantum Channel](@ref
  tutorial-quantum-channel) for a runnable `put!`/`take!` example.
