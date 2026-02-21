"""Applies DEJMPS protocol on two-qubit pairs"""
function purify!(N::Network, memL::RegRef, memR::RegRef, ancL::RegRef, ancR::RegRef)
    success = DEJMPSProtocol(N.param.ϵ_g, N.param.ξ)(memL, memR, ancL, ancR)

    delete!(N.ent_list, ancL)
    delete!(N.ent_list, ancR)
    if !success
        delete!(N.ent_list, memL)
        delete!(N.ent_list, memR)
    end
end

"""Performs DEJMPS protocol between two nodes"""
function purify!(N::Network, nodeL::Node, nodeR::Node)
    q = N.param.q

    ent_list = [(nodeL.right[q], N.ent_list[nodeL.right[q]]) for q in 1:q if nodeL.right[q] in keys(N.ent_list) && N.ent_list[nodeL.right[q]].reg == nodeR.left]

    while length(ent_list) > 1
        (memL, memR) = popfirst!(ent_list)
        (ancL, ancR) = popfirst!(ent_list)
        purify!(N, memL, memR, ancL, ancR)
    end

    if length(ent_list) == 1
        (qL, qR) = ent_list[1]
        QuantumSavory.traceout!(qL); delete!(N.ent_list, qL)
        QuantumSavory.traceout!(qR); delete!(N.ent_list, qR)
    end
end
purify!(N::Network, nodeL::Int, nodeR::Int) = purify!(N, N.nodes[nodeL], N.nodes[nodeR])


"""Performs DEJMPS protocol network-wide"""
function purify!(N::Network)
    times::Vector{Float64} = []
    for node in N.nodes
        if !isnothing(node.connectedTo_R)
            purify!(N, node, node.connectedTo_R)
            push!(times, getCommTime(N, node, node.connectedTo_R))
        end
    end
    tickTime!(N, maximum(times))
end