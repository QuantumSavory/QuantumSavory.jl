using HDF5

"""
$TYPEDEF

Structure containing all the recorded observables from an `EntanglementConsumer` protocol, along its stored metadata.

$FIELDS
"""
@kwdef struct EntanglementConsumerLog
    """times at which the `EntanglementConsumer` protocol recorded observables from consuming entangled pairs."""
    time::Vector{Float64} = Float64[]
    """values of the first observable recorded from consuming entangled pairs."""
    obs1::Vector{Float64} = Float64[]
    """values of the second observable recorded from consuming entangled pairs."""   
    obs2::Vector{Float64} = Float64[]
    """metadata stored along with the log, if any (only applicable for HDF5 format)."""
    metadata::Dict{String,Any} = Dict{String,Any}()
end

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
    _log::EntanglementConsumerLog = EntanglementConsumerLog()
end

function EntanglementConsumer(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...)
    return EntanglementConsumer(;sim, net, nodeA, nodeB, kwargs...)
end
function EntanglementConsumer(net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...)
    return EntanglementConsumer(get_time_tracker(net), net, nodeA, nodeB; kwargs...)
end

permits_virtual_edge(::EntanglementConsumer) = true

function _reset_entanglement_consumer_log!(prot::EntanglementConsumer, metadata::Dict{String,Any})
    empty!(prot._log.time)
    empty!(prot._log.obs1)
    empty!(prot._log.obs2)
    empty!(prot._log.metadata)

    for key in keys(metadata)
        prot._log.metadata[key] = metadata[key]
    end
end

@resumable function (prot::EntanglementConsumer)(metadata::Dict{String,Any} = Dict{String,Any}())
    regA = prot.net[prot.nodeA]
    regB = prot.net[prot.nodeB]
    _reset_entanglement_consumer_log!(prot, metadata)
    
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
        push!(prot._log.time, now(prot.sim))
        push!(prot._log.obs1, ob1)
        push!(prot._log.obs2, ob2)
        unlock(q1)
        unlock(q2)
        if !isnothing(prot.period)
            @yield timeout(prot.sim, prot.period::Float64)
        end
    end
end

function _save_log_hdf5(file_name::String, log::EntanglementConsumerLog)
    h5open(file_name, "w") do file
        write(file, "t", log.time)
        write(file, "obs1", log.obs1)
        write(file, "obs2", log.obs2)

        metadata_keys = collect(keys(log.metadata))
        metadata_values = Vector{String}()
        for key in metadata_keys
            push!(metadata_values, string(log.metadata[key]))
        end

        write(file, "metadata_keys", metadata_keys)
        write(file, "metadata_values", metadata_values)
    end
end

function _save_log_csv(file_name::String, log::EntanglementConsumerLog)
    open(file_name, "w") do file
        println(file, "time,obs1,obs2")
        for i in eachindex(log.time)
            println(file, "$(log.time[i]),$(log.obs1[i]),$(log.obs2[i])")
        end
    end
end

function _save_log_txt(file_name::String, log::EntanglementConsumerLog)
    open(file_name, "w") do file
        pretty_table(file, hcat(log.time, log.obs1, log.obs2), header=["time", "obs1", "obs2"], formatters=ft_printf("%16.8f"))
    end
end

function _save_log(file_name::Union{String,Nothing}, log::EntanglementConsumerLog)
    if isnothing(file_name)
        return
    end

    if endswith(file_name, ".h5") || endswith(file_name, ".hdf5")
        _save_log_hdf5(file_name, log)
    elseif endswith(file_name, ".csv")
        _save_log_csv(file_name, log)
    elseif endswith(file_name, ".txt")
        _save_log_txt(file_name, log)
    else
        throw(ArgumentError("Unsupported file format for saving EntanglementConsumer log."))
    end
end

"""
    save_entanglement_consumer_log(file_name::String, prot::EntanglementConsumer)

Saves the log of an `EntanglementConsumer` protocol to a file specified by 
`file_name`. The log contains the time and resulting observables from querying 
the two nodes of entangled pairs, and any associated metadata. The file format 
is determined by the extension of `file_name` (supports `.h5`, `.csv`, and 
`.txt`). Metadata is only saved for HDF5 format.

# Arguments
- `file_name::String`: The name of the file to save the logged observables to.
- `prot::EntanglementConsumer`: The `EntanglementConsumer` protocol instance whose log is to be saved.
"""
function save_entanglement_consumer_log(file_name::String, prot::EntanglementConsumer)
    _save_log(file_name, prot._log)
end

function _load_log_hdf5(file_name::String)::EntanglementConsumerLog
    time = Vector{Float64}()
    obs1 = Vector{Float64}()
    obs2 = Vector{Float64}()
    metadata = Dict{String,Any}()

    h5open(file_name, "r") do file
        time = read(file, "t")
        obs1 = read(file, "obs1")
        obs2 = read(file, "obs2")

        metadata_keys = read(file, "metadata_keys")
        metadata_values = read(file, "metadata_values")

        for (key, value) in zip(metadata_keys, metadata_values)
            metadata[key] = value
        end
    end

    return EntanglementConsumerLog(time, obs1, obs2, metadata)
end

function _load_log_csv(file_name::String)::EntanglementConsumerLog
    time = Vector{Float64}()
    obs1 = Vector{Float64}()
    obs2 = Vector{Float64}()

    open(file_name, "r") do file
        readline(file) # skip header
        for line in eachline(file)
            t, o1, o2 = split(line, ",")
            push!(time, parse(Float64, t))
            push!(obs1, parse(Float64, o1))
            push!(obs2, parse(Float64, o2))
        end
    end

    return EntanglementConsumerLog(time, obs1, obs2)
end

function _load_log_txt(file_name::String)::EntanglementConsumerLog
    time = Vector{Float64}()
    obs1 = Vector{Float64}()
    obs2 = Vector{Float64}()

    open(file_name, "r") do file
        readline(file) # skip header
        for line in eachline(file)
            t, o1, o2 = split(line)
            push!(time, parse(Float64, t))
            push!(obs1, parse(Float64, o1))
            push!(obs2, parse(Float64, o2))
        end
    end

    return EntanglementConsumerLog(time, obs1, obs2)
end

"""
    load_entanglement_consumer_log(file_name::String) -> EntanglementConsumerLog

Loads an `EntanglementConsumerLog` from a file specified by `file_name`. The 
file format is determined by the extension of `file_name` (supports `.h5`, 
`.csv`, and `.txt`).

# Arguments
- `file_name::String`: The name of the file to load the log from.
"""
function load_entanglement_consumer_log(file_name::String)::EntanglementConsumerLog
    if endswith(file_name, ".h5") || endswith(file_name, ".hdf5")
        return _load_log_hdf5(file_name)
    elseif endswith(file_name, ".csv")
        return _load_log_csv(file_name)
    elseif endswith(file_name, ".txt")
        return _load_log_txt(file_name)
    else
        throw(ArgumentError("Unsupported file format for loading EntanglementConsumer log."))
    end
end

