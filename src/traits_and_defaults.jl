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

using InteractiveUtils 
import PrettyTables: pretty_table

function available_slot_types()
    types = subtypes(QuantumStateTrait)

    docs = [(type = T, doc = Base.Docs.doc(T)) for T in types] #TODO: edge case: no doc

    pretty_table(docs; crop = :none, header = ["Type", "Docstring"])

    return docs
end