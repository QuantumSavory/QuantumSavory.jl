"""A background describing the T₁ decay of a two-level system."""
struct T1Decay <: AbstractBackground
    t1
end

"""A background describing the T₂ dephasing of a two-level system."""
struct T2Dephasing <: AbstractBackground
    t2
end
