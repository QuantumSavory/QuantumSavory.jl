# ProtocolZoo for Users

Open this file when:

- you want reusable long-running protocol components;
- you need entanglers, swappers, trackers, cutoff logic, switch, MBQC, or QTCP
  controllers;
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
- `GraphStateConstructor`, `GraphToResource`, `PurifierBellMeasurements`, and
  `MBQCPurificationTracker` for distributed graph-state and MBQC purification
  workflows. These four types are exported by the nested
  `QuantumSavory.ProtocolZoo.MBQCEntanglementDistillation` module.

## Protocol Discovery

- Use `protocol_schemas()` for the deterministic built-in catalog.
- Use `protocol_schema(ProtocolType)` for typed constructor parameters,
  attachment, node roles, and virtual-edge capability. The catalog contains all
  13 exported concrete built-in protocols, including the switch and MBQC
  families above.
- Use `protocol_attachment(ProtocolType)` when only the network, node, or edge
  ownership scope is needed.
- An attachment describes where a process is owned, not every node it acts on.
  `ProtocolNodeRole` records those statically configured nodes separately, with
  `OneNode` or `ManyNodes` cardinality and `AttachmentBound` or `Configurable`
  binding.
- Attachment-bound roles are injected and excluded from constructor metadata.
  Configurable roles remain advertised constructor fields.
- Attachment and virtual-edge accessors derive from the protocol schema; custom
  protocols must register one before configuration tooling can inspect them.
- Constructor fields exclude `sim`, `net`, attachment-bound roles, and private
  runtime storage.

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
- Use `tag_head_schemas()` for the deterministic catalog of standard named tag
  heads and `tag_head_schema(TagType)` for ordered field metadata.
- If a workflow depends on swap updates or deletion notices, include `EntanglementTracker`.
- Use `protocol_log_context(prot)...` with Julia's standard logging macros.
  Custom protocols should overload `protocol_log_context` to return simulation
  fields, a protocol symbol, and an immutable ordered `nodes` tuple.
- Do not discover protocols by walking subtypes or parsing docstrings.
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
