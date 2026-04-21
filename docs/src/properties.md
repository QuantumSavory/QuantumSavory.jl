# Properties


When creating a new register, you can specify what type of physical system it will contain in each slot,
e.g. a [`Qubit`](@ref) or a qudit or a harmonic oscillator or a propagating wave packet.


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
