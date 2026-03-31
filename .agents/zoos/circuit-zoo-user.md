# CircuitZoo for Users

Open this file when:

- you need a reusable local quantum routine;
- you want swapping, purification, fusion, or superdense-coding logic without writing gates by hand;
- you need a circuit object, not a long-running protocol.

Do not use this file for:

- protocol composition;
- circuit implementation internals;
- extension or review of `AbstractCircuit`.

Use `.agents/zoos/circuit-zoo-dev.md` for those.

## What CircuitZoo Is For

- `CircuitZoo` is the reusable local-quantum layer.
- Circuits act immediately on chosen slots.
- They do not wait on messages or own control flow over time.
- If you need scheduling, retries, or resource discovery, use `ProtocolZoo` instead.

## Current Families To Know

- Entanglement swapping:
  - `EntanglementSwap`
  - `LocalEntanglementSwap`
- Purification:
  - `Purify2to1`
  - `Purify3to1`
  - `PurifyStringent`
  - `PurifyExpedient`
- Other circuits:
  - `SDEncode`
  - `SDDecode`
  - `Fusion`

## Common Workflow

```julia
using QuantumSavory
using QuantumSavory.CircuitZoo

a = Register(3)
b = Register(3)
bell = StabilizerState("XX ZZ")
for i in 1:3
    initialize!((a[i], b[i]), bell)
end

ok = Purify3to1(:Z, :Y)(a[1], b[1], a[2], a[3], b[2], b[3])
```

## Usage Guidance

- Use full circuits when you want end-to-end local quantum logic.
- Use `...Node` variants only when you are deliberately splitting one distributed routine into per-node halves.
- Expect some circuits to consume measured or sacrificial qubits.
- Use `CircuitZoo` inside your own protocols when the quantum logic is standard but the control flow is custom.

## Good Docs And Examples To Open Next

- `docs/src/API_CircuitZoo.md`
- `docs/src/zoos_as_building_blocks.md`
- `docs/src/howto/firstgenrepeater/firstgenrepeater.md`
- `../writeup/zoos.tex`
- `../writeup/Overview.tex`

## Common Mistakes

- Using `ProtocolZoo` when a simple local circuit is enough.
- Using a `...Node` half when the full circuit is what you need.
- Forgetting that some successful runs still consume helper qubits.
