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

"""Display all available slot types in QuantumSavory along with their documentation.

The `InteractiveUtils` package must be installed and imported."""
function available_slot_types end