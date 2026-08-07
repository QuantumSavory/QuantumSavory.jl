# [Modeling Registers, Factorization, and Time](@id modeling-registers-time)

QuantumSavory's register model is designed for realistic hardware, not just
ideal qubit circuits. A `Register` can hold different kinds of subsystems,
attach different backends to them, and declare the background processes they
experience.

```julia
Register(
    [Qubit(), Qumode()],
    [CliffordRepr(), QuantumOpticsRepr()],
    [T2Dephasing(10.0), AmplitudeDamping(0.2)],
)
```

That is useful because many hardware models are naturally hybrid. A memory
qubit, an optical mode, and a communication channel do not all want the same
mathematics. QuantumSavory lets one model describe them together instead of
forcing everything into one approximation.

## Registers Describe The Model At The Right Level

At the register level, the user states:

- what kinds of subsystems exist,
- which numerical representation is preferred for each slot, and
- which background processes are always present.

This keeps the model close to the hardware description. You describe the
system once, then reuse that description across protocols, measurements, and
backend experiments.

## Symbolic Structure Controls Initial Factorization

Quantum states are not eagerly expanded into one giant Hilbert space. During
initialization, QuantumSavory splits a top-level symbolic tensor. For example,
`X1 ⊗ Z1` can install two separate factor states. Wrapping the complete product
in `SProjector(X1 ⊗ Z1)` or `MixedState(X1 ⊗ Z1)` instead installs one joint
state, while `SProjector(X1) ⊗ SProjector(Z1)` remains structurally factorized.

This is a structural rule, not a general separability test. Numeric backend
states and symbolic expressions nested inside another operation are not
inspected to discover independent factors.

This matters because memory cost grows very quickly for general wavefunction
methods. Keeping independent parts factored out means memory grows with the
size of the entangled clusters you have created, not with the full product
space of the whole register.

An `apply!` call over separate factors composes them and stores the resulting
joint state. An `observable` over separate factors composes a temporary state
without changing their stored factorization. Measurements and trace-out
operations reduce the selected stored states as required.

## Scheduler Time And Register Time Are Separate

A `ConcurrentSim.timeout` advances the event scheduler only. It does not apply
register backgrounds. Each subsystem instead carries a local access time, and
register operations advance background evolution according to their own time
contract.

When an operation is intended to occur at scheduler time, pass that time
explicitly:

```julia
t = now(sim)
initialize!(reg[1], Z1; time=t)
apply!(reg[1], H; time=t)
value = observable(reg[1], Z; time=t)
outcome = project_traceout!(reg[1], Z; time=t)
```

If `time` is omitted, `initialize!` leaves the slot's local time unchanged and
`apply!` synchronizes the selected slots only to their greatest recorded local
time. `observable` and `project_traceout!` do not evolve backgrounds without an
explicit time. Plain `traceout!` never advances time. A circuit helper that
does not accept `time` must be preceded by `uptotime!(refs, now(sim))` when it
is intended to run at scheduler time.

This demand-driven time handling does two useful things:

- it avoids spending work on subsystems that nobody has touched yet, and
- it lets protocol code stay focused on protocol logic instead of bookkeeping.

Different parts of the same model can therefore sit at different local times
until an operation explicitly advances or synchronizes them. QuantumSavory
does not infer `now(sim)` from a register operation.

## Noise Is Declared Once, Then Lowered By The Backend

Noise models are attached to the register when it is created. The user says
what physical process is present, such as decay or dephasing, and QuantumSavory
handles how that process is represented by the chosen numerical backend.

This is a productivity feature. You do not need to manually derive or rederive
backend-specific Kraus maps, Lindblad terms, or twirled approximations each
time you change representation. The backend performs the needed lowering on
demand.

## Why This Modeling Style Matters

Taken together, factorized storage, declarative noise, symbolic frontend
objects, and framework-managed time let you change the fidelity or efficiency
of a model without rebuilding it from scratch. That is what makes QuantumSavory
useful for rapid iteration: the conceptual model stays stable while the
simulation strategy changes.

## Where To Go Next

- Read [Register Networks](@ref register-networks) for how registers are
  assigned to graph vertices and connected by channels.
- Read [Properties](@ref) for how subsystem types and preferred
  representations are attached to slots.
- Read [Background Noise Processes](@ref) for how background processes are
  declared and inspected.
- Read [Register Interface API](register_interface.md) for the precise
  operations that act on register slots and states.
