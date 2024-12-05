"""
$TYPEDEF

A network control protocol that is connection oriented, non-distributed and centralized. The generation of 
random requests is abstracted with picking a random path from all available paths in the arbitrary network
between Alice and Bob. The controller is located at one of the nodes in the network from where it messages all
the other nodes.

$TYPEDFIELDS

See also [`RequestTracker`](@ref)
"""
@kwdef struct NetController <: AbstractProtocol
    """Time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """A network graph of registers"""
    net::RegisterNet
    """The number of requests to be generated per cycle"""
    n::Int
    """The node in the network where the control protocol is physically located, ideally a centrally located node"""
    node::Int
    """duration of a single full cycle of entanglement generation and swapping along a specific path"""
    ticktock::Float64
end

@resumable function (prot::NetController)()
    paths = collect(Graphs.all_simple_paths(prot.net.graph, 1, 8))
    n_reg = length(prot.net.registers)
    mb = messagebuffer(prot.net, prot.node)
    while true
        draw = (randperm(n_reg))[1:prot.n]
        for i in 1:prot.n
            path = paths[draw[i]]
            @debug "Running Entanglement Distribution on path $(path) @ $(now(prot.sim))"
            for i in 1:length(path)-1
                msg = Tag(EntanglementRequest, path[i], path[i+1], 1)
                if prot.node == path[i]
                    put!(mb, msg)
                else
                    put!(channel(prot.net, prot.node=>msg[2]; permit_forward=true), msg)
                end
            end
            
            for i in 2:length(path)-1
                msg = Tag(SwapRequest, path[i], 1)
                if prot.node == path[i]
                    put!(mb, msg)
                else
                    put!(channel(prot.net, prot.node=>msg[2];permit_forward=true), msg)
                end
            end
            @yield timeout(prot.sim, prot.ticktock)
        end
    end
end

"""
$TYPEDEF

A network control protocol that is connection oriented, non-distributed and centralized. The controller is located at one of the nodes in the network from where it messages all
the other nodes' [`RequestTracker`](@ref) protocols when it receives [`DistributionRequest`](@ref) from the [`RequestGenerator`](@ref).

$TYPEDFIELDS

See also [`RequestGenerator`](@ref), [`RequestTracker`](@ref)
"""
@kwdef struct Controller <: AbstractProtocol
    """Time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """A network graph of registers"""
    net::RegisterNet
    """The node in the network where the control protocol is physically located, ideally a centrally located node"""
    node::Int
    """A matrix for the object containing physical graph metadata for the network"""
    path_mat::Matrix{Union{Float64, PathMetadata}}
end

@resumable function (prot::Controller)()
    mb = messagebuffer(prot.net, prot.node)
    while true
        workwasdone = true
        while workwasdone
            workwasdone = false
            msg = querydelete!(mb, DistributionRequest, ❓, ❓, ❓)
            if !isnothing(msg)
                (msg_src, (_, req_src, req_dst, rounds)) = msg
                if typeof(prot.path_mat[req_src, req_dst]) <: Number
                    prot.path_mat[req_src, req_dst] = PathMetadata(prot.net.graph, req_src, req_dst, Int(length(prot.net[1].staterefs)/2))
                end
                path_id = path_selection(prot.sim, prot.path_mat[req_src, req_dst])
                path = prot.path_mat[req_src, req_dst].paths[path_id]
                if isnothing(path_id)
                    @debug "Request failed, all paths reserved"
                end

                @debug "Running Entanglement Distribution on path $(path) @ $(now(prot.sim))"
                for i in 1:length(path)-1
                    msg = Tag(EntanglementRequest, path[i], path[i+1], 1)
                    if prot.node == path[i]
                        put!(mb, msg)
                    else
                        put!(channel(prot.net, prot.node=>msg[2]; permit_forward=true), msg)
                    end
                end
                
                for i in 2:length(path)-1
                    msg = Tag(SwapRequest, path[i], rounds, path[i-1], path[i+1], 0)
                    if prot.node == path[i]
                        put!(mb, msg)
                    else
                        put!(channel(prot.net, prot.node=>msg[2];permit_forward=true), msg)
                    end
                end
            end
            @debug "Controller @$(prot.node): Starting message wait at $(now(prot.sim)) with MessageBuffer containing: $(mb.buffer)"
            @yield wait(mb)
            @debug "Controller @$(prot.node): Message wait ends at $(now(prot.sim))"
        end
    end
end


"""
$TYPEDEF

A network control protocol that is connection less, non-distributed and centralized. The controller is located at one of the nodes in the network from where it messages all
the other nodes' [`RequestTracker`](@ref) protocols when it receives [`DistributionRequest`](@ref) from the [`RequestGenerator`](@ref).

$TYPEDFIELDS

See also [`RequestGenerator`](@ref), [`RequestTracker`](@ref)
"""
@kwdef struct CLController <: AbstractProtocol
    """Time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """A network graph of registers"""
    net::RegisterNet
    """The node in the network where the control protocol is physically located, ideally a centrally located node"""
    node::Int
end

@resumable function (prot::CLController)()
    mb = messagebuffer(prot.net, prot.node)
    while true
        workwasdone = true
        while workwasdone
            workwasdone = false
            msg = querydelete!(mb, DistributionRequest, ❓, ❓, ❓)
            if !isnothing(msg)
                (msg_src, (_, req_src, req_dst, rounds)) = msg
                for v in vertices(prot.net)
                    if v != req_src && v != req_dst
                        msg = Tag(SwapRequest, v, rounds, req_src, req_dst, 1)
                        if prot.node == v
                            put!(mb, msg)
                        else
                            put!(channel(prot.net, prot.node=>msg[2];permit_forward=true), msg)
                        end
                    end
                end
            end
            @debug "Controller @$(prot.node): Starting message wait at $(now(prot.sim)) with MessageBuffer containing: $(mb.buffer)"
            @yield wait(mb)
            @debug "Controller @$(prot.node): Message wait ends at $(now(prot.sim))"
        end
    end
end