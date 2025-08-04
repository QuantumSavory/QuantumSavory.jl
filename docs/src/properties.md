# Properties


When creating a new registers, you can specify what type of physical system it will contain in each slot,
e.g. a [`Qubit`](@ref) or a qudit or a harmonic oscillator or a propagating wave packet.


To see all available slot types in QuantumSavory along with their documentation, run the following code:


```@example
using QuantumSavory


using InteractiveUtils
import PrettyTables: pretty_table, tf_markdown


types = QuantumSavory.available_slot_types()
pretty_table(types; linebreaks = true)
```