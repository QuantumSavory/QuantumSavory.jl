"""
$TYPEDEF

Classical correction message sent by [`TeleportationProt`](@ref) after the
sender performs the Bell-basis measurement.

The correction fields store the raw `project_traceout!` outcomes: `1` means no
Pauli correction, while `2` means applying the corresponding Pauli.

$TYPEDFIELDS
"""
@kwdef struct TeleportationCorrection
    "the node that performed the Bell-basis measurement"
    sender::Int
    "the sender slot that held the input state"
    input_slot::Int
    "the sender slot that held the local half of the Bell pair"
    entangled_slot::Int
    "the receiver slot where the teleported state is restored"
    output_slot::Int
    "whether the receiver should apply a `Z` correction (`1` or `2`)"
    z_correction::Int
    "whether the receiver should apply an `X` correction (`1` or `2`)"
    x_correction::Int
end
Base.show(io::IO, tag::TeleportationCorrection) = print(io, "Teleportation correction from $(tag.sender).$(tag.input_slot) via .$(tag.entangled_slot) to .$(tag.output_slot): Z$(tag.z_correction) X$(tag.x_correction)")
Tag(tag::TeleportationCorrection) = Tag(TeleportationCorrection, tag.sender, tag.input_slot, tag.entangled_slot, tag.output_slot, tag.z_correction, tag.x_correction)

"""
$TYPEDEF

Metadata added by [`TeleportationProt`](@ref) to the receiver slot after the
classical corrections have been applied.

$TYPEDFIELDS
"""
@kwdef struct TeleportedState
    "the node that provided the input state"
    sender::Int
    "the sender slot that held the input state"
    input_slot::Int
    "the sender slot that held the local half of the Bell pair"
    entangled_slot::Int
    "the receiver slot now holding the teleported state"
    output_slot::Int
end
Base.show(io::IO, tag::TeleportedState) = print(io, "Teleported state from $(tag.sender).$(tag.input_slot) via .$(tag.entangled_slot) to .$(tag.output_slot)")
Tag(tag::TeleportedState) = Tag(TeleportedState, tag.sender, tag.input_slot, tag.entangled_slot, tag.output_slot)

function findteleportationpair(prot)
    reg = prot.net[prot.sender]
    receiver_slot_query = isnothing(prot.receiver_slot) ? ❓ : prot.receiver_slot::Int
    results = queryall(reg, EntanglementCounterpart, prot.receiver, receiver_slot_query; locked=false, assigned=true)
    if isnothing(prot.entangledslot)
        results = [r for r in results if r.slot.idx != prot.inputslot]
    else
        results = [r for r in results if r.slot.idx == prot.entangledslot]
    end
    isempty(results) && return nothing
    return first(results)
end

"""
$TYPEDEF

Teleport one qubit state from `sender.inputslot` into an entangled slot at
`receiver`.

The protocol consumes one Bell pair tagged with [`EntanglementCounterpart`](@ref),
performs the Bell-basis measurement at the sender, sends a
[`TeleportationCorrection`](@ref) message over the classical network, applies
the Pauli corrections at the receiver, and tags the output slot with
[`TeleportedState`](@ref).

The sender and receiver do not need to be adjacent in the network as long as a
classical route exists and a tagged entangled pair already connects them.

$TYPEDFIELDS
"""
@kwdef struct TeleportationProt <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex index of the node that starts with the input state"""
    sender::Int
    """the vertex index of the node that receives the teleported state"""
    receiver::Int
    """the sender slot containing the input state to be teleported"""
    inputslot::Int
    """the sender slot holding the local half of the Bell pair (`nothing` to choose the first suitable tagged slot)"""
    entangledslot::Union{Int,Nothing} = nothing
    """the receiver slot holding the remote half of the Bell pair (`nothing` to use the slot from the sender's tag)"""
    receiver_slot::Union{Int,Nothing} = nothing
    """fixed busy time immediately before the local Bell-basis measurement"""
    local_busy_time::Float64 = 0.0
    """how long to wait before retrying if no usable input/pair is available (`nothing` for waiting on tag changes)"""
    retry_lock_time::Union{Float64,Nothing} = 0.1
    """how many teleportation rounds to run (`-1` for infinite)"""
    rounds::Int = 1
    """tag added to the receiver slot after correction, or `nothing` to skip output tagging"""
    outputtag::Union{DataType,Nothing} = TeleportedState
end

function TeleportationProt(sim::Simulation, net::RegisterNet, sender::Int, receiver::Int, inputslot::Int; kwargs...)
    return TeleportationProt(;sim, net, sender, receiver, inputslot, kwargs...)
end

TeleportationProt(net::RegisterNet, sender::Int, receiver::Int, inputslot::Int; kwargs...) = TeleportationProt(get_time_tracker(net), net, sender, receiver, inputslot; kwargs...)

permits_virtual_edge(::TeleportationProt) = true

@resumable function (prot::TeleportationProt)()
    if !isnothing(prot.entangledslot) && prot.entangledslot == prot.inputslot
        throw(ArgumentError("`TeleportationProt` needs distinct `inputslot` and `entangledslot` values."))
    end

    rounds = prot.rounds
    round = 1
    last_output = nothing
    sender_reg = prot.net[prot.sender]
    receiver_reg = prot.net[prot.receiver]
    inputslot = sender_reg[prot.inputslot]

    while rounds != 0
        if !isassigned(inputslot) || islocked(inputslot)
            if isnothing(prot.retry_lock_time)
                @debug "$(timestr(prot.sim)) TeleportationProt($(compactstr(sender_reg)), $(compactstr(receiver_reg))), round $(round): input slot unavailable, waiting for tag changes..."
                @yield onchange(sender_reg, Tag)
            else
                @debug "$(timestr(prot.sim)) TeleportationProt($(compactstr(sender_reg)), $(compactstr(receiver_reg))), round $(round): input slot unavailable, waiting a fixed amount of time..."
                @yield timeout(prot.sim, prot.retry_lock_time::Float64)
            end
            continue
        end

        pair_ = findteleportationpair(prot)
        if isnothing(pair_)
            if isnothing(prot.retry_lock_time)
                @debug "$(timestr(prot.sim)) TeleportationProt($(compactstr(sender_reg)), $(compactstr(receiver_reg))), round $(round): no Bell pair found, waiting for tag changes..."
                @yield onchange(sender_reg, Tag) | onchange(receiver_reg, Tag)
            else
                @debug "$(timestr(prot.sim)) TeleportationProt($(compactstr(sender_reg)), $(compactstr(receiver_reg))), round $(round): no Bell pair found, waiting a fixed amount of time..."
                @yield timeout(prot.sim, prot.retry_lock_time::Float64)
            end
            continue
        end

        pair = pair_::QueryOnRegResult
        entangledslot = pair.slot
        outputslot = receiver_reg[pair.tag[3]]

        @yield lock(inputslot) & lock(entangledslot) & lock(outputslot)

        current_sender_tag = query(entangledslot, EntanglementCounterpart, prot.receiver, outputslot.idx; locked=true, assigned=true)
        current_receiver_tag = query(outputslot, EntanglementCounterpart, prot.sender, entangledslot.idx; locked=true, assigned=true)
        if !isassigned(inputslot) || isnothing(current_sender_tag) || isnothing(current_receiver_tag)
            unlock(inputslot)
            unlock(entangledslot)
            unlock(outputslot)
            continue
        end

        untag!(entangledslot, current_sender_tag.id)
        untag!(outputslot, current_receiver_tag.id)

        @yield timeout(prot.sim, prot.local_busy_time)
        uptotime!((inputslot, entangledslot, outputslot), now(prot.sim))
        apply!((inputslot, entangledslot), CNOT)
        apply!(inputslot, H)

        zmeas = project_traceout!(inputslot, Z)
        xmeas = project_traceout!(entangledslot, Z)

        msg = Tag(TeleportationCorrection, prot.sender, inputslot.idx, entangledslot.idx, outputslot.idx, Int(zmeas), Int(xmeas))
        put!(channel(prot.net, prot.sender=>prot.receiver; permit_forward=true), msg)
        @debug "$(timestr(prot.sim)) TeleportationProt($(compactstr(sender_reg)), $(compactstr(receiver_reg))), round $(round): sent correction message `$(msg)`"

        correction = @yield querydelete_wait!(
            messagebuffer(prot.net, prot.receiver),
            TeleportationCorrection,
            prot.sender,
            inputslot.idx,
            entangledslot.idx,
            outputslot.idx,
            ❓,
            ❓,
        )
        correction.tag[7] == 2 && apply!(outputslot, X)
        correction.tag[6] == 2 && apply!(outputslot, Z)

        if !isnothing(prot.outputtag)
            tag!(outputslot, prot.outputtag::DataType, prot.sender, inputslot.idx, entangledslot.idx, outputslot.idx)
        end
        last_output = (prot.receiver, outputslot.idx)

        unlock(inputslot)
        unlock(entangledslot)
        unlock(outputslot)
        rounds == -1 || (rounds -= 1)
        round += 1
    end

    return last_output
end
