"""
$TYPEDEF

A protocol running between two nodes, checking periodically for any entangled pairs between the two nodes and consuming/emptying the qubit slots.

This protocol permits virtual edges, meaning it can operate between any two nodes in the network regardless of whether they are physically connected by an edge.

$FIELDS
"""
@kwdef struct EntanglementConsumer <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex index of node A"""
    nodeA::Int
    """the vertex index of node B"""
    nodeB::Int
    """time period between successive queries on the nodes (`nothing` for queuing up and waiting for available pairs)"""
    period::Union{Float64,Nothing} = 0.1
    """tag type which the consumer is looking for -- the consumer query will be `query(node, EntanglementConsumer.tag, remote_node)` and it will be expected that `remote_node` possesses the symmetric reciprocal tag; defaults to `EntanglementCounterpart`"""
    tag::Any = EntanglementCounterpart
    """stores the time and resulting observable from querying nodeA and nodeB for `EntanglementCounterpart`"""
    _log::Vector{@NamedTuple{t::Float64, obs1::Float64, obs2::Float64}} = @NamedTuple{t::Float64, obs1::Float64, obs2::Float64}[]
    """stores any additional metadata that should be logged alongside the time and observables"""
    _metadata::Union{Dict{String,Any},Nothing} = nothing
    """file name to save the log to when the protocol finishes (supports `.h5` and `.csv` formats). If `nothing`, the log will not be saved to a file."""
    _file_name::Union{String,Nothing} = nothing
end

function EntanglementConsumer(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...)
    return EntanglementConsumer(;sim, net, nodeA, nodeB, kwargs...)
end
function EntanglementConsumer(net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...)
    return EntanglementConsumer(get_time_tracker(net), net, nodeA, nodeB; kwargs...)
end

function _save_entanglement_consumer_log(prot::EntanglementConsumer)
    if !isnothing(prot._file_name)
        _save_entanglement_consumer_log(prot._file_name, prot)
    end
end

permits_virtual_edge(::EntanglementConsumer) = true

@resumable function (prot::EntanglementConsumer)()
    regA = prot.net[prot.nodeA]
    regB = prot.net[prot.nodeB]
    empty!(prot._log)
    
    while true
        query1 = query(regA, prot.tag, prot.nodeB, ❓; locked=false, assigned=true) # TODO Need a `querydelete!` dispatch on `Register` rather than using `query` here followed by `untag!` below
        if isnothing(query1)
            if isnothing(prot.period)
                @debug "$(timestr(prot.sim)) EntanglementConsumer($(compactstr(regA)), $(compactstr(regB))): query on first node found no entanglement. Waiting on tag updates in $(compactstr(regA))."
                @yield onchange(regA, Tag)
            else
                @debug "$(timestr(prot.sim)) EntanglementConsumer($(compactstr(regA)), $(compactstr(regB))): query on first node found no entanglement. Waiting a fixed amount of time."
                @yield timeout(prot.sim, prot.period::Float64)
            end
            continue
        else
            query2 = query(regB, prot.tag, prot.nodeA, query1.slot.idx; locked=false, assigned=true)
            if isnothing(query2) # in case EntanglementUpdate hasn't reached the second node yet, but the first node has the EntanglementCounterpart
                if isnothing(prot.period)
                    @debug "$(timestr(prot.sim)) EntanglementConsumer($(compactstr(regA)), $(compactstr(regB))): query on second node found no entanglement (yet...). Waiting on tag updates in $(compactstr(regB))."
                    @yield onchange(regB, Tag)
                else
                    @debug "$(timestr(prot.sim)) EntanglementConsumer($(compactstr(regA)), $(compactstr(regB))): query on second node found no entanglement (yet...). Waiting a fixed amount of time."
                    @yield timeout(prot.sim, prot.period::Float64)
                end
                continue
            end
        end

        q1 = query1.slot
        q2 = query2.slot
        @yield lock(q1) & lock(q2)

        @debug "$(timestr(prot.sim)) EntanglementConsumer($(compactstr(regA)), $(compactstr(regB))): queries successful, consuming entanglement between .$(q1.idx) and .$(q2.idx)"
        untag!(q1, query1.id)
        untag!(q2, query2.id)
        # TODO do we need to add EntanglementHistory or EntanglementDelete and should that be a different EntanglementHistory since the current one is specifically for Swapper
        # TODO currently when calculating the observable we assume that EntanglerProt.pairstate is always (|00⟩ + |11⟩)/√2, make it more general for other states
        ob1 = observable((q1, q2), Z⊗Z)
        ob2 = observable((q1, q2), X⊗X)
        if isnothing(ob1) || isnothing(ob2)
            @error "$(timestr(prot.sim)) EntanglementConsumer($(compactstr(regA)), $(compactstr(regB))): dropping stale pair between .$(q1.idx) and .$(q2.idx)"
            traceout!(regA[q1.idx], regB[q2.idx])
            unlock(q1)
            unlock(q2)
            continue
        end
        ob1 = real(ob1)
        ob2 = real(ob2)

        traceout!(regA[q1.idx], regB[q2.idx])
        push!(prot._log, (now(prot.sim), ob1, ob2))
        unlock(q1)
        unlock(q2)
        if !isnothing(prot.period)
            @yield timeout(prot.sim, prot.period::Float64)
        end
    end

    if !isnothing(prot._file_name)
        _save_entanglement_consumer_log(prot) # TODO this is never reached (the loop above never exits)!!!
    end
end

