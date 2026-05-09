The directly supported reusable protocol layer is `ProtocolZoo`.

The docs describe it as including:

- entanglement generation and swapping protocols;
- metadata tracking helpers;
- consumer and cutoff protocols;
- switch-style protocols;
- and QTCP-related controllers and message types.

In user-facing terms, the common stack includes:

- `EntanglerProt`
- `SwapperProt`
- `EntanglementTracker`
- `CutoffProt`
- `EntanglementConsumer`

and more specialized families such as:

- `SimpleSwitchDiscreteProt`
- `EndNodeController`
- `NetworkNodeController`
- `LinkController`

These are ready-to-run `AbstractProtocol` objects launched with `@process`.

What usually requires custom implementation is:

- protocol logic that does not fit the built-in reusable components;
- a new coordination pattern or tag schema;
- or a workflow where the local quantum routine is standard but the control flow
  is not.

In those cases, the package expects you to write either:

- your own `@resumable` process; or
- your own `AbstractProtocol` subtype.

If the quantum part is standard but the control logic is custom, the idiomatic
split is to reuse `CircuitZoo` for the local quantum routine and write your own
protocol around it.

