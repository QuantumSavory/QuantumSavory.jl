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

## States Stay Factored Until Interaction Requires More

Quantum states are not eagerly expanded into one giant Hilbert space. If two
subsystems have not interacted, QuantumSavory keeps them as separate state
objects. When an operation actually couples them, only then does the simulator
compose the needed joint state.

This matters because memory cost grows very quickly for general wavefunction
methods. Keeping independent parts factored out means memory grows with the
size of the entangled clusters you have created, not with the full product
space of the whole register.

Measurements, observables, and trace-out operations follow the same idea. They
operate on the needed subsystems and only merge or reduce states when the
physics requires it.

## Time Is Tracked For You

Background evolution is not something you manually weave through every gate and
measurement call. Each subsystem carries its own local simulation time, and the
framework advances it only when an operation, observable, or synchronization
point demands it.

This demand-driven time handling does two useful things:

- it avoids spending work on subsystems that nobody has touched yet, and
- it lets protocol code stay focused on protocol logic instead of bookkeeping.

Different parts of the same model can therefore sit at different effective
times until an interaction forces them to be synchronized.

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

- Read [Properties](@ref) for how subsystem types and preferred
  representations are attached to slots.
- Read [Background Noise Processes](@ref) for how background processes are
  declared and inspected.
- Read [Register Interface API](register_interface.md) for the precise
  operations that act on register slots and states.
