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
    sim::Simulation
    net::RegisterNet
    n::Int
    node::Int # The node in the network where the control protocol is physically located/running from, ideally a node central in  the network.
    ticktock::Float64
end

@resumable function (prot::NetController)()
    paths = collect(Graphs.all_simple_paths(prot.net.graph, 1, 8))
    n_reg = length(prot.net.registers)
    while true
        draw = (randperm(n_reg))[1:prot.n]
        for i in 1:prot.n #parallelize this
            path = paths[draw[i]]
            @debug "Running Entanglement Distribution on path $(path) @ $(now(prot.sim))"
            for i in 1:length(path)-1
                msg = Tag(EntanglementRequest, path[i], path[i+1], 1)
                put!(channel(prot.net, prot.node=>msg[2]; permit_forward=true), msg)
            end
            @yield timeout(prot.sim, prot.ticktock)
            for i in 2:length(path)-1
                msg = Tag(SwapRequest, path[i], 1)
                put!(channel(prot.net, prot.node=>msg[2];permit_forward=true), msg)
            end
            @yield timeout(prot.sim, prot.ticktock)
        end
    end
end