function random_index(arr)
    return rand(keys(arr))
end

"""
Find a qubit pair in a register that is suitable for performing a swap by [`SwapperProt`](@ref) according to the given predicate and choosing functions, satisfying the agelimit(if any) of the qubits
"""
function findswapablequbits(net, node, pred_low, pred_high, choose_low, choose_high; agelimit=nothing)
    reg = net[node]
    low_nodes  = [
        n for n in queryall(reg, EntanglementCounterpart, pred_low, ❓; locked=false, assigned=true)
        if isnothing(agelimit) || !isolderthan(n.slot, agelimit)
    ]
    high_nodes = [
        n for n in queryall(reg, EntanglementCounterpart, pred_high, ❓; locked=false, assigned=true)
        if isnothing(agelimit) || !isolderthan(n.slot, agelimit)
    ]

    (isempty(low_nodes) || isempty(high_nodes)) && return nothing
    il = choose_low((n.tag[2] for n in low_nodes)) # TODO make [2] into a nice named property
    ih = choose_high((n.tag[2] for n in high_nodes))
    return (low_nodes[il], high_nodes[ih])
end

"""Find an empty unlocked slot in a given [`Register`](@ref).

```jldoctest
julia> reg = Register(3); initialize!(reg[1], X); lock(reg[2]);

julia> findfreeslot(reg) == reg[3]
true

julia> lock(findfreeslot(reg));

julia> findfreeslot(reg) |> isnothing
true
```
"""
function findfreeslot(reg::Register; randomize=false, margin=0)
    n_slots = length(reg.staterefs)
    freeslots = sum((!isassigned(reg[i]) for i in 1:n_slots))
    if freeslots >= margin
        perm = randomize ? randperm : (x->1:x)
        for i in perm(n_slots)
            slot = reg[i]
            islocked(slot) || isassigned(slot) || return slot
        end
    end
end


struct NotAssignedError <: Exception # TODO use this in all places where we are throwing something on isassigned (maybe rename to IsAssignedError and check whether we need to keep `f` as part of it (might already be provided by the stacktrace) and check it does not allocate even when the error is not triggered)
    msg
    f
end

function Base.showerror(io::IO, err::NotAssignedError)
    print(io, "NotAssignedError: ")
    println(io, err.msg)
    println("In function: $(err.f)")
end

"""Check whether a qubit has existed for a time more than its cutoff/coherence time"""
function isolderthan(slot::RegRef, time_left::Float64)
    if !isassigned(slot) throw(NotAssignedError("Slot must be assigned with a quantum state before checking coherence.", isolderthan)) end
    id = query(slot, QuantumSavory.ProtocolZoo.EntanglementCounterpart, ❓, ❓).id
    slot_time  = slot.reg.tag_info[id][3]
    return (now(get_time_tracker(slot))) - slot_time > time_left
end
