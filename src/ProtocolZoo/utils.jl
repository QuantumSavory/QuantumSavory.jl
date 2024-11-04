"""
$TYPEDEF

A struct containing the physical graph metadata for a network. The latest workload data is only available
at the node where the [`RequestGenerator`](@ref) runs, but every node has access to a copy for referencing paths based on indices
passed through the `DistributionRequest` tag/message.

$TYPEDFIELDS
"""
@kwdef struct PathMetadata
    """The vector of paths between the user pair"""
    paths::Vector{Vector{Int}}
    """The vector containing the workload information of a path"""
    workloads::Vector{Int}
    """The number of slots available at each node. Scalar if all are same, vector otherwise."""
    capacity::Union{Vector{Int}, Int}
    """Number of failed requests due to high request traffic"""
    failures::Ref{Int}
end

function PathMetadata(graph::SimpleGraph{Int64}, src::Int, dst::Int, caps::Union{Vector{Int}, Int}; failures=Ref{Int}(0))
    paths = sort(collect(all_simple_paths(graph, src, dst)); by = x->length(x))
    workloads = zeros(length(paths))
    PathMetadata(paths, workloads, caps, failures)
end


"""
A simple path selection algorithm for connection oriented networks.
"""
function path_selection(sim, pathobj::PathMetadata) 
    for i in 1:length(pathobj.paths)
        capacity = isa(pathobj.capacity, Number) ? pathobj.capacity : pathobj.capacity[i]
        if pathobj.workloads[i]<capacity
            pathobj.workloads[i] += 1
            @process unreserve_path(sim, pathobj, i)
            return i
        end
    end
    pathobj.failures +=1
    return nothing
end

@resumable function unreserve_path(sim, pathobj::PathMetadata, i)
    @yield timeout(sim, 0.5)
    @debug "Path $(pathobj.paths[i]) workload reduced"
    pathobj.workloads[i] -= 1
end


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