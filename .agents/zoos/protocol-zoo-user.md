# ProtocolZoo for Users

Open this file when:

- you want reusable long-running protocol components;
- you need entanglers, swappers, trackers, cutoff logic, switch controllers, or QTCP controllers;
- you are composing a network stack out of existing protocol objects.

Do not use this file for:

- tracker internals;
- tag serialization details;
- concurrency review or race debugging.

Use `.agents/zoos/protocol-zoo-dev.md` for those.

## What ProtocolZoo Is For

- `ProtocolZoo` is the reusable control-plane layer.
- Protocols are callable objects that run inside the discrete-event simulator.
- They compose through shared tags and message buffers rather than direct protocol-to-protocol wiring.

## Common Stack

- `EntanglerProt` creates link-level entanglement and tags both ends.
- `SwapperProt` consumes two tagged links and performs a local swap.
- `EntanglementTracker` keeps remote metadata and corrections coherent after swaps and deletions.
- `CutoffProt` removes stale entanglement.
- `EntanglementConsumer` acts as a sink or observer for completed long-range pairs.

Other specialized families:

- `SimpleSwitchDiscreteProt` for switch-style setups.
- `EndNodeController`, `NetworkNodeController`, and `LinkController` for the QTCP stack.

## Common Workflow

```julia
using QuantumSavory
using QuantumSavory.ProtocolZoo
using ConcurrentSim

sim = Simulation()
net = RegisterNet([Register(2), Register(2)])
prot = EntanglerProt(sim, net, 1, 2; rounds=-1)
@process prot()
```

## Usage Guidance

- Launch protocol objects with `@process prot()`.
- Compose protocols over one `RegisterNet`.
- Use standard typed tags documented in `docs/src/standard_protocol_tags.md`
  when user-written protocols should communicate with `ProtocolZoo` protocols.
- Custom tags are appropriate for protocol-local metadata that no zoo protocol
  needs to understand.
- Custom tag heads passed to `EntanglerProt` or `EntanglementConsumer` must be
  declared as concrete subtypes of `AbstractTag`; `nothing` is supported only
  by the entangler to disable tagging.
- If a workflow depends on swap updates or deletion notices, include `EntanglementTracker`.
- Use `protocol_log_context(prot)...` with Julia's standard logging macros.
  Custom protocols should overload `protocol_log_context` to return simulation
  fields, a protocol symbol, and an immutable ordered `nodes` tuple.
- Use `CircuitZoo` instead when all you need is a local gate sequence.

## Good Docs And Examples To Open Next

- `docs/src/API_ProtocolZoo.md`
- `docs/src/standard_protocol_tags.md`
- `docs/src/zoos_as_building_blocks.md`
- `docs/src/discreteeventsimulator.md`
- `docs/src/howto/firstgenrepeater/firstgenrepeater.md`
- `docs/src/howto/repeatergrid/repeatergrid.md`
- `docs/src/howto/simpleswitch/simpleswitch.md`
- `examples/firstgenrepeater/README.md`
- `examples/repeatergrid/README.md`
- `examples/simpleswitch/README.md`

## Common Mistakes

- Launching a swapper or cutoff flow without the metadata-tracking logic it depends on.
- Re-implementing standard control logic when a zoo protocol already exists.
- Treating a protocol object like a pure function instead of a long-running process.
