"""Performs an entanglement swap between two qubits in the Network"""
function ent_swap!(N::Network, remoteL::RegRef, localL::RegRef, localR::RegRef, remoteR::RegRef)
    N.swapcircuit(localL, remoteL, localR, remoteR)

    N.ent_list[remoteL] = remoteR
    N.ent_list[remoteR] = remoteL
    delete!(N.ent_list, localL)
    delete!(N.ent_list, localR)
end


"""Performs entanglement swapping in a node"""
function ent_swap!(N::Network, node::Node)
    q = N.param.q

    ent_list_L = [(N.ent_list[node.left[q]], node.left[q]) for q in 1:q if node.left[q] in keys(N.ent_list)]
    ent_list_R = [(node.right[q], N.ent_list[node.right[q]]) for q in 1:q if node.right[q] in keys(N.ent_list)]

    for ((remoteL, localL), (localR, remoteR)) in zip(ent_list_L, ent_list_R)
        ent_swap!(N, remoteL, localL, localR, remoteR)
    end

    len_diff = length(ent_list_L) - length(ent_list_R)
    while len_diff > 0
        (remoteL, localL) = pop!(ent_list_L)
        traceout!(localL); delete!(N.ent_list, localL)
        traceout!(remoteL); delete!(N.ent_list, remoteL)
        len_diff -= 1
    end
    while len_diff < 0
        (localR, remoteR) = pop!(ent_list_R)
        traceout!(localR); delete!(N.ent_list, localR)
        traceout!(remoteR); delete!(N.ent_list, remoteR)
        len_diff += 1
    end

    node.connectedTo_L.connectedTo_R = node.connectedTo_R
    node.connectedTo_R.connectedTo_L = node.connectedTo_L
    node.isActive = false
end


"""Performs entanglement swapping at level i"""
function ent_swap!(N::Network, i::Int)
    n = N.param.n

    for j in 1:n         # Implement multi-threading (after thread safety)
        if j % 2^i == (2^i)/2
            ent_swap!(N, N.nodes[j+1])
        end
    end
end


"""Performs entanglement swapping in all Repeaters in the Network"""
function ent_swap!(N::Network)
    n = N.param.n

    for i in Int64.(1:log2(n))
        if N.param.distil_sched[i]
            purify!(N)
        end
        
        ent_swap!(N, i)
    end
end
