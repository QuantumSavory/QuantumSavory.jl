"""An abstract type for the various types of states that can be given to [`Register`](@ref) slots, e.g. qubit, harmonic oscillator, etc."""
abstract type QuantumStateTrait end

"""An abstract type for the various background processes that might be inflicted upon a [`Register`](@ref) slot, e.g. decay, dephasing, etc."""
abstract type AbstractBackground end

"""Specifies that a given register slot contains qubits."""
struct Qubit <: QuantumStateTrait end
"""Specifies that a given register slot contains qumodes."""
struct Qumode <: QuantumStateTrait end

# TODO move these definitions to a neater place
default_repr(::Qubit) = QuantumOpticsRepr()
default_repr(::Qumode) = QuantumOpticsRepr()

public available_slot_types, constructor_metadata

"""Return the available public slot types along with their documentation.

Used to make a slot type available to tools like QuantumSavory Studio.

Concrete direct and indirect subtypes of [`QuantumStateTrait`](@ref) are discovered on
each call. The defining binding of each type must be public. The `InteractiveUtils`
and `REPL` standard libraries must be loaded to activate this optional method."""
function available_slot_types end

"""Return documented constructor fields for a type.

Used to make a constructor available to tools like QuantumSavory Studio.

Each entry has the fields `field`, `type`, and `doc`. Undocumented fields and fields
whose names begin with an underscore are omitted. The `InteractiveUtils` and `REPL`
standard libraries must be loaded to activate this optional method."""
function constructor_metadata end
