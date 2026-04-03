QuantumSavory has two transport planes.

Classical transport:

- send with `channel(net, src => dst)` and `put!(...)`;
- receive from `messagebuffer(net, dst)`;
- payloads are `Tag`s;
- this is for control traffic such as swap requests, entanglement updates, and
  other protocol messages.

Quantum transport:

- use `QuantumChannel(sim, delay)` for a standalone delayed link;
- use `qchannel(net, src => dst)` for a network-attached direct edge;
- payloads are assigned quantum slots, not tags;
- the moved slot carries its entanglement with it.

The usage pattern is intentionally different:

```julia
put!(channel(net, 1 => 2), Tag(:swap_request))
msg = querydelete!(messagebuffer(net, 2), :swap_request)
```

```julia
put!(qchannel(net, 1 => 2), net[1, 1])
@yield take!(qchannel(net, 1 => 2), net[2, 1])
```

Rules worth remembering:

- classical receive-side code normally works against the node’s message buffer;
- `permit_forward=true` applies only to classical traffic;
- the destination slot for quantum `take!` must be empty;
- `tag!` is for register slots, not for message buffers.

