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
    """tag type which the consumer is looking for; defaults to `EntanglementCounterpart`, where reciprocal tags must also agree on pair ID"""
    tag::Any = EntanglementCounterpart
    """stores the time and resulting observable from querying nodeA and nodeB for `EntanglementCounterpart`"""
    _log::Vector{@NamedTuple{t::Float64, obs1::Float64, obs2::Float64}} = @NamedTuple{t::Float64, obs1::Float64, obs2::Float64}[]
end

function EntanglementConsumer(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...)
    return EntanglementConsumer(;sim, net, nodeA, nodeB, kwargs...)
end
function EntanglementConsumer(net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...)
    return EntanglementConsumer(get_time_tracker(net), net, nodeA, nodeB; kwargs...)
end

permits_virtual_edge(::EntanglementConsumer) = true

@resumable function (prot::EntanglementConsumer)()
    regA = prot.net[prot.nodeA]
    regB = prot.net[prot.nodeB]
    while true
        use_pair_id = prot.tag === EntanglementCounterpart
        query1 = if use_pair_id
            query(regA, prot.tag, prot.nodeB, ❓, ❓; locked=false, assigned=true)
        else
            query(regA, prot.tag, prot.nodeB, ❓; locked=false, assigned=true)
        end # TODO Need a `querydelete!` dispatch on `Register` rather than using `query` here followed by `untag!` below
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
            pair_id = use_pair_id ? query1.tag[4] : nothing
            query2 = if use_pair_id
                query(regB, prot.tag, prot.nodeA, query1.slot.idx, pair_id; locked=false, assigned=true)
            else
                query(regB, prot.tag, prot.nodeA, query1.slot.idx; locked=false, assigned=true)
            end
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
        # Re-query under lock and require reciprocal pair IDs. The slot tuple is
        # routing metadata; `pair_id` is the actual entangled-pair identity.
        query1 = if use_pair_id
            query(q1, prot.tag, prot.nodeB, q2.idx, pair_id; locked=true, assigned=true)
        else
            query(q1, prot.tag, prot.nodeB, q2.idx; locked=true, assigned=true)
        end
        query2 = if use_pair_id
            query(q2, prot.tag, prot.nodeA, q1.idx, pair_id; locked=true, assigned=true)
        else
            query(q2, prot.tag, prot.nodeA, q1.idx; locked=true, assigned=true)
        end
        if isnothing(query1) || isnothing(query2)
            @debug "$(timestr(prot.sim)) EntanglementConsumer($(compactstr(regA)), $(compactstr(regB))): queries stale after locking, retrying."
            unlock(q1)
            unlock(q2)
            continue
        end

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
end

"""
$TYPEDEF

A struct representing the metadata for an entanglement consumer log file.

$FIELDS
"""
@kwdef struct EntanglementConsumerLogMetadata
    """A description of the simulation or experiment."""
    description::String = ""
    """The name of the simulator used for the simulation or experiment."""
    simulator::String = ""
    """A dictionary containing additional metadata related to the QuantumSavory simulation or experiment."""
    quantumsavory_metadata::Dict{String,Any} = Dict{String,Any}()
end

"""
$TYPEDEF

A struct representing the simulation log for an entanglement consumer log file.

$FIELDS
"""
@kwdef struct EntanglementConsumerLogSimulationLog
    """A vector of time points corresponding to the logged data."""
    time::Vector{Float64} = zeros(Float64,0)
    """A matrix containing the logged data, where each row corresponds to a time point and each column corresponds to a different observable."""
    state::Matrix{Float64} = zeros(Float64,0,0)
end

"""
$TYPEDEF

A struct representing an entanglement consumer log file.

$FIELDS
"""
@kwdef struct EntanglementConsumerLog
    """The version of the QuantumSavory file format used for this log file."""
    format_version::UInt64 = UInt64(0)
    """The minor version of the QuantumSavory file format used for this log file."""
    format_version_minor::UInt64 = UInt64(0)
    """The format of the log data (e.g., "pauli_observables", "state_vector")."""
    log_format::String = ""
    """The reference state used in the simulation (e.g., "bell_pair")."""
    reference_state::String = ""
    """The simulation mode used in the simulation (e.g., "stateful", "repeated_single_shot")."""
    simulation_mode::String = ""
    """The metadata associated with the entanglement consumer log file."""
    metadata::EntanglementConsumerLogMetadata = EntanglementConsumerLogMetadata()
    """The simulation log data for the entanglement consumer log file."""
    simulation_log::EntanglementConsumerLogSimulationLog = EntanglementConsumerLogSimulationLog()
end

# Default constructor for EntanglementConsumerLog
function EntanglementConsumerLog(file::Any)
    throw(MethodError(EntanglementConsumerLog, (file,)))
end

