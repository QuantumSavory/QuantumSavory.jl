# TODO better constructors
# TODO am I overusing Ref
struct StateRef
    state::Base.RefValue{Any} # TODO it would be nice if this was not abstract but `uptotime!` converts between types... maybe make StateRef{T} state::RefValue{T} and a new function that swaps away the backpointers in the appropriate registers
    registers::Vector{Any} # TODO Should be Vector{Register}, but right now we occasionally set it to nothing to deal with padded storage
    registerindices::Vector{Int}
    StateRef(state::Base.RefValue{S}, registers, registerindices) where {S} = new(state, registers, registerindices)
end

StateRef(state, registers, registerindices) = StateRef(Ref{Any}(copy(state)), registers, registerindices) # TODO same as above, this should not be forced to Any

"""
The main data structure in `QuantumSavory`, used to represent a quantum register in an arbitrary formalism.
"""
struct Register # TODO better type description / TODO mutable struct with immutable fields to remove the refs
    traits::Vector{Any}
    reprs::Vector{Any}
    backgrounds::Vector{Any}
    staterefs::Vector{Union{Nothing,StateRef}}
    stateindices::Vector{Int}
    accesstimes::Vector{Float64} # TODO do not hardcode the type
    locks::Vector{Any}
    tag_info::Dict{Int128, @NamedTuple{tag::Tag, slot::Int, time::Float64}}
    guids::Vector{Int128}
    netparent::Ref{Any}
    netindex::Ref{Int}
    tag_waiter::Ref{AsymmetricSemaphore} # TODO This being a ref is a bit of code smell... but we also want to be able to have registers that are not linked to a net so we need to be able to have this field un-initialized
end

function Register(traits, reprs, bg, sr, si, at)
    env = ConcurrentSim.Simulation()
    Register(traits, reprs, bg, sr, si, at, [ConcurrentSim.Resource(env) for _ in traits], Dict{Int128, Tuple{Tag, Int64, Float64}}(), Int128[], nothing, 0, Ref(AsymmetricSemaphore(env)))
end

Register(traits,reprs,bg,sr,si) = Register(traits,reprs,bg,sr,si,zeros(length(traits)))
Register(traits,reprs,bg) = Register(traits,reprs,bg,fill(nothing,length(traits)),zeros(Int,length(traits)),zeros(length(traits)))
Register(traits,bg::Base.AbstractVecOrTuple{<:Union{Nothing,<:AbstractBackground}}) = Register(traits,default_repr.(traits),bg)
Register(traits,reprs::Base.AbstractVecOrTuple{<:AbstractRepresentation}) = Register(traits,reprs,fill(nothing,length(traits)))
Register(traits) = Register(traits,default_repr.(traits))
Register(nqubits::Int) = Register([Qubit() for _ in 1:nqubits])
Register(nqubits::Int,repr::AbstractRepresentation) = Register(fill(Qubit(),nqubits),fill(repr,nqubits))
Register(nqubits::Int,bg::AbstractBackground) = Register(fill(Qubit(),nqubits),fill(bg,nqubits))

"""
A reference to a [`Register`](@ref) slot, convenient for use with functions like [`apply!`](@ref), etc.

```jldoctest
julia> r = Register(2)
       initialize!(r[1], X₁)
       observable(r[1], X)
0.9999999999999998 + 0.0im
```
"""
struct RegRef
    reg::Register
    idx::Int
end

const RegOrRegRef = Union{Register,RegRef}

get_register(r::RegRef) = r.reg
get_register(r::Register) = r

"""The state stored at a given register slot."""
function stateof end
stateof(r::RegRef) = stateof(r.reg, r.idx) # TODO introduce Slot and make RegRef an alias of Slot
stateof(r::Register, i::Int) = r.staterefs[i]

"""The underlying backend-dependent quantum state numerical object for a given state of multiple register slots."""
function quantumstate end
quantumstate(::Nothing) = nothing
quantumstate(s::StateRef) = s.state[]

"""The slots which are entangled into the given state reference."""
function slots end
slots(::Nothing) = RegRef[]
slots(s::StateRef) = RegRef[r[i] for (r,i) in zip(s.registers, s.registerindices)]


function onchange_tag(r::RegOrRegRef)
    register = get_register(r)
    return lock(register.tag_waiter[])
end
