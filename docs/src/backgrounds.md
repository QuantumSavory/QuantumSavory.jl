# Background Noise Processes


For each subsystem (slot in the register), you also specify what background processes and noise parameters describe it.
For instance, it could be a [`T1Decay`](@ref) or [`T2Dephasing`](@ref) process, or a coherent error, or a non-Markovian bath.
It is supported by all backends (but maybe with twirling, e.g. to support `T1Decay` in a Clifford simulation).


To see all available background types in QuantumSavory along with their documentation, run the following code:


```@example subtype
using QuantumSavory


using InteractiveUtils
import PrettyTables: pretty_table, tf_markdown


types = QuantumSavory.available_background_types()
pretty_table(types; linebreaks = true)
```


If you want to introspect these noise processes, you can use the [`paulinoise`](@ref), [`krausops`](@ref), and [`lindbladop`](@ref) functions.


You can also display all argument types of a given background type. For example, this shows the constructors for [`PauliNoise`](@ref).


```@example arg
using QuantumSavory #hide


using InteractiveUtils #hide
import PrettyTables: pretty_table, tf_markdown #hide


metadata = QuantumSavory.constructor_metadata(PauliNoise)
pretty_table(metadata; linebreaks = true)
```