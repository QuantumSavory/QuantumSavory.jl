# Properties

When you create a register, each slot can declare what kind of physical system
it represents. This is how QuantumSavory knows whether a slot should behave
like a qubit, a bosonic mode, or another kind of subsystem.

## Why Slot Properties Matter

Slot properties are not just labels. They affect:

- what default state is sensible for that slot,
- which symbolic states and operations can be lowered into a numerical backend,
- which observables and measurements are natural for that subsystem, and
- which backend choices are a good fit for the model.

This matters because realistic nodes are often heterogeneous. A single device
may combine memory qubits, optical modes, communication qubits, or other
subsystems with different physics.

```julia
hybrid_node = Register(
    [Qubit(), Qumode()],
    [CliffordRepr(), QuantumOpticsRepr()],
)
```

That small declaration is already doing useful work. It says that the first
slot is best treated as a qubit-like system, the second as a mode-like system,
and that they may want different numerical representations.

## Why This Improves Productivity

Being explicit about slot types lets the same protocol code work with models
that are closer to the actual hardware. You do not need to flatten everything
into ideal qubits just to get started, and you do not need to manually track
which mathematical formalism belongs to each subsystem.

This is also what makes the symbolic frontend important and valuable. You can describe a
state or operation at the conceptual level and let QuantumSavory lower it using
the slot properties and chosen backend.

## Available Slot Types

The slot types currently available in QuantumSavory are:


```@example
using QuantumSavory # hide


using InteractiveUtils # hide
import PrettyTables: pretty_table # hide

function pt_to_html(args...; kwargs...) # hide
    str = pretty_table(String, args...; kwargs...) # hide
    return Base.HTML(str) # hide
end # hide

types = QuantumSavory.available_slot_types() # hide
pt_to_html(types; backend = :html, show_column_labels = false) # hide
```

## Where To Go Next

- Read [Modeling Registers, Factorization, and Time](@ref
  modeling-registers-time) for the larger modeling picture.
- Read [Background Noise Processes](@ref) for the other half of the physical
  description attached to register slots.
