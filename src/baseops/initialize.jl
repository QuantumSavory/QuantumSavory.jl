export initialize!, newstate

function newstate end

function initialize!(reg::Register,i::Int; time=nothing)
    s = newstate(reg.traits[i], reg.reprs[i])
    initialize!(reg,i,s; time=time)
end
initialize!(r::RegRef; time=nothing) = initialize!(r.reg, r.idx; time)

"""
Set the state of a given set of registers.

`initialize!([regA,regB], [slot1,slot2], state)` would
set the state of the given slots in the given registers to `state`.
`state` can be any supported state representation,
e.g., kets or density matrices from `QuantumOptics.jl`
or tableaux from `QuantumClifford.jl`.
"""
function initialize!(regs::Vector{Register},indices::Vector{Int},state; time=nothing)
    length(regs)==length(indices)==nsubsystems(state) || throw(DimensionMismatch(lazy"Attempting to initialize a set of registers with a state that does not have the correct number of subsystems."))
    stateref = StateRef(state, collect(regs), collect(indices))
    for (si,(reg,ri)) in enumerate(zip(regs,indices))
        if isassigned(reg,ri) # TODO decide if this is an error or a warning or nothing
            throw("error") # TODO be more descriptive
        end
        reg.staterefs[ri] = stateref
        reg.stateindices[ri] = si
        !isnothing(time) && (reg.accesstimes[ri] = time)
    end
    stateref
end
initialize!(refs::Vector{RegRef}, state; time=nothing) = initialize!([r.reg for r in refs], [r.idx for r in refs], state; time)
initialize!(refs::NTuple{N,RegRef}, state; time=nothing) where {N} = initialize!([r.reg for r in refs], [r.idx for r in refs], state; time) # TODO temporary array allocated here
initialize!(reg::Register,i::Int,state; time=nothing) = initialize!([reg],[i],state; time)
initialize!(r::RegRef, state; time=nothing) = initialize!(r.reg, r.idx, state; time)
initialize!(r::Vector{Register},i::Vector{Int},state::Symbolic; time=nothing) = initialize!(r,i,express(state,consistent_representation(r,i,state)); time)

"""For a given set of registers, return what representation of states can be used such that it would work for all of them."""
function consistent_representation end # TODO actually implement this
