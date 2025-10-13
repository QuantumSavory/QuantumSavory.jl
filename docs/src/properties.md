# Properties


When creating a new register, you can specify what type of physical system it will contain in each slot,
e.g. a [`Qubit`](@ref) or a qudit or a harmonic oscillator or a propagating wave packet.


The slot types currently available in QuantumSavory are:

```@example
using QuantumSavory # hide


using InteractiveUtils # hide
import PrettyTables: pretty_table, tf_markdown # hide


types = QuantumSavory.available_slot_types() # hide
pretty_table(types; backend = :html) # hide
```
