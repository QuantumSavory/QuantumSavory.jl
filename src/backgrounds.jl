export T1Decay, T2Dephasing, Depolarization, PauliNoise, AmplitudeDamping

"""A background describing the T₁ decay of a two-level system."""
struct T1Decay <: AbstractBackground
    t1
end

"""A background describing the T₂ dephasing of a two-level system."""
struct T2Dephasing <: AbstractBackground
    t2
end

"""A depolarization background."""
struct Depolarization <: AbstractBackground
    τ
end

"""A Pauli noise background."""
struct PauliNoise <: AbstractBackground
    τˣ
    τʸ
    τᶻ
end

"""A depolarization background."""
struct AmplitudeDamping <: AbstractBackground
    τ
end
