# Register Interface for Users

Open this file when:

- you need to create `Register`s or `RegisterNet`s;
- you are using `initialize!`, `apply!`, `observable`, `project_traceout!`, or `traceout!`;
- you are writing protocol code against `RegRef`s like `reg[i]`.

Do not use this file for:

- `StateRef` internals;
- backend implementation hooks;
- performance or representation internals.

Use `.agents/registers/register-internals-and-backend-hooks.md` for those.

## Mental Model

- `Register` is the hardware-facing container. Each slot has a subsystem type, a preferred representation, and optional background noise.
- `RegRef` is the normal handle you pass around. `reg[1]` is the public unit of interaction.
- `RegisterNet` is the graph-backed collection of registers used for network simulations and shared simulation time.
- States stay factorized until interactions force them together.
- Background evolution is lazy. You declare it once at construction time, and QuantumSavory advances it when an operation or readout needs it.

## Common Workflow

```julia
using QuantumSavory

reg = Register([Qubit(), Qubit()])
initialize!(reg[1:2], StabilizerState("XX ZZ"))
apply!((reg[1], reg[2]), CNOT)
value = observable(reg[1:2], SProjector(StabilizerState("XX ZZ")))
bit = project_traceout!(reg[1], Z)
traceout!(reg[2])
```

Typical network setup:

```julia
net = RegisterNet([Register(2), Register(2)]; classical_delay=1.0, quantum_delay=5.0)
initialize!((net[1, 1], net[2, 1]), StabilizerState("XX ZZ"))
```

## Public APIs To Prefer

- Construction:
  - `Register(...)`
  - `RegisterNet(...)`
- Slot handles and inspection:
  - `reg[i]`
  - `stateof`
  - `quantumstate`
  - `slots`
  - `isassigned`
- State preparation and evolution:
  - `initialize!`
  - `apply!`
  - `uptotime!`
- Readout and state reduction:
  - `observable`
  - `project_traceout!`
  - `traceout!`
- Protocol-side resource control:
  - `lock`
  - `unlock`
  - `islocked`

## Usage Guidance

- Prefer symbolic states and operations unless you explicitly need a backend object.
- Put subsystem traits, preferred representations, and background processes on the register at construction time.
- Write protocol code against `RegRef`s, not backend state objects.
- Use `RegisterNet` early if registers will participate in one simulation. It unifies time tracking and networking APIs.
- Use locks when multiple simulated processes can touch the same slot.

## Good Docs And Examples To Open Next

- `docs/src/manual.md`
- `docs/src/architecture.md`
- `docs/src/register_interface.md`
- `docs/src/modeling_registers_and_time.md`
- `docs/src/properties.md`
- `examples/firstgenrepeater/README.md`
- `examples/firstgenrepeater_v2/README.md`

## Common Mistakes

- Treating `StateRef` as a public API. It is not.
- Forgetting that protocol concurrency still needs locking on shared slots.
- Picking the default representation and assuming it is the best performance choice for every workload.
- Mixing unrelated backend-native objects into user-facing code when a symbolic state or operation would do.
