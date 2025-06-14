import QuantumSavory

nsteps(p::NetworkParam) = Int64(log2(p.n)) + sum(p.distil_sched) + 1
nsteps(N::Network) = nsteps(N.param)

"""Converts a Network into a QuantumSavory.RegisterNet"""
function toRegisterNet(N::Network)
    registers::Vector{Register} = []

    for node in N.nodes
        if node.isActive
            if !isnothing(node.left)
                push!(registers, node.left)
            end
            if !isnothing(node.right)
                push!(registers, node.right)
            end
        end
    end

    return QuantumSavory.RegisterNet(registers)
end

"""Returns a figure representing the current state of the Network"""
function netplot(N::Network)
    n = N.param.n
    q = N.param.q
    
    coords::Vector{Point2f} = []
    push!(coords, Point2f(2, 1))
    for i in 1:n
        if N.nodes[i+1].isActive
            push!(coords, Point2f(10*i+1, 1))
            push!(coords, Point2f(10*i+2, 1))
        end
    end
    push!(coords, Point2f(10*(n)+1, 1))
    
    empty!(N.ax)
    net = toRegisterNet(N)
    registernetplot!(N.ax, net, registercoords=coords)

    return N.fig
end


"""Gets the communication times between two indexed nodes"""
function getCommTime(N::Network, i::Int, j::Int)
    @assert 1 <= i <= length(N.nodes) "i must be in [1, length(N.nodes)]"
    @assert i <= j <= length(N.nodes) "j must be in [i, length(N.nodes)]"
    
    return sum(N.param.t_comms[i:j-1])
end
getCommTime(N::Network, nodeL::Node, nodeR::Node) = getCommTime(N, findfirst(x->x==nodeL, N.nodes), findfirst(x->x==nodeR, N.nodes))

function tickTime!(N::Network, t::Float64)
    N.curTime += t
    uptotime!(N, N.curTime)
end


"""Returns the Quantum Bit Error Rate of the network"""
function getQBER(N::Network)
    y = length(N.ent_list) ÷ 2
    if y == 0
        return 1.0, 1.0
    end

    Q_x_sum = 0.0
    Q_z_sum = 0.0
    for (q1, q2) in N.ent_list
        if (q1.reg == N.nodes[1].right && q2.reg == N.nodes[end].left)
            ρ = BellState(q1)
            Q_x_sum += ρ.b + ρ.d
            Q_z_sum += ρ.c + ρ.d
        end
    end

    Q_x = Q_x_sum / y
    Q_z = Q_z_sum / y
    return Q_x, Q_z
end

"""Returns r_secure"""
function r_secure(Q_x::Float64, Q_z::Float64)
    @assert 0 <= Q_x <= 1 "Q_x must be in [0, 1]"
    @assert 0 <= Q_z <= 1 "Q_z must be in [0, 1]"
    
    h_x = (-Q_x * log2(Q_x)) - ((1 - Q_x) * log2(1 - Q_x)); h_x = isnan(h_x) ? -Inf : h_x
    h_y = (-Q_z * log2(Q_z)) - ((1 - Q_z) * log2(1 - Q_z)); h_y = isnan(h_y) ? -Inf : h_y

    return max(1 - h_x - h_y, 0)
end
