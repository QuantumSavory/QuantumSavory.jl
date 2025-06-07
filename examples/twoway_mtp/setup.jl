using QuantumSavory
using QuantumOptics
using QuantumSymbolics
using QuantumInterface

using Random
using CairoMakie
include("./noisyops/CircuitZoo.jl")


"""Defines a node in the Quantum Network"""
mutable struct Node
    left::Union{Register, Nothing}
    right::Union{Register, Nothing}

    isActive::Bool
    connectedTo_L::Union{Node, Nothing}
    connectedTo_R::Union{Node, Nothing}

    function Node(type::Symbol, q::Int; T2::Float64=0.0)
        @assert    0 <  q                   "q must be positive"
        @assert    0 <= T2                  "T2 must be non-negative"

        qL = Register(q, T2Dephasing(T2))
        qR = Register(q, T2Dephasing(T2))

        if type == :Alice
            return new(nothing, qR, true, nothing, nothing)
        elseif type == :Bob
            return new(qL, nothing, true, nothing, nothing)
        elseif type == :Repeater
            return new(qL, qR, true, nothing, nothing)
        end; throw(ArgumentError("Invalid node type"))
    end
end


struct NetworkParam
    n::Int64
    q::Int64

    T2::Float64
    F::Float64
    p_ent::Float64
    ϵ_g::Float64
    ξ::Float64

    t_comms::Vector{Float64}
    distil_sched::Vector{Bool}

    function NetworkParam(n::Int64, q::Int64; T2::Float64, F::Float64, p_ent::Float64, ϵ_g::Float64, ξ::Float64, t_comms::Vector{Float64}, distil_sched::Vector{Bool})
        @assert 2 <=   n           "N must be non-negative"
        @assert ispow2(n)
        @assert 0 <=   q            "q must be non-negative"
        @assert 0 <=  T2            "T2 must be non-negative"
        @assert 0 <=   F   <= 1     "Fidelity must be in [0, 1]"
        @assert 0 <= p_ent <= 1     "p_ent must be in [0, 1]"
        @assert 0 <=  ϵ_g  <= 1     "ϵ_g must be in [0, 1]"
        @assert 0 <=   ξ   <= 1     "ξ must be in [0, 1]"
        @assert all(x -> 0 <= x, t_comms)       "All node distances must be non-negative"
        @assert length(t_comms) == n            "Number of node distances must be n"
        @assert length(distil_sched) == log2(n) "Number of distillation schedules must be log2(n)"

        new(n, q, T2, F, p_ent, ϵ_g, ξ, t_comms, distil_sched)
    end
end


"""Defines a Quantum Network with Alice & Bob and Repeaters in between"""
mutable struct Network      # mutable due to curTime
    param::NetworkParam
    rng::AbstractRNG

    curTime::Float64        
    nodes::Vector{Node}
    ent_list::Dict{RegRef, RegRef}

    swapcircuit::EntanglementSwap
    purifycircuit::DEJMPSProtocol

    function Network(p::NetworkParam; rng::AbstractRNG=Random.GLOBAL_RNG)
        nodes = Vector{Node}()
        push!(nodes, Node(:Alice, p.q; p.T2))
        for _ in 1:p.n-1
            push!(nodes, Node(:Repeater, p.q; p.T2))
        end
        push!(nodes, Node(:Bob, p.q; p.T2))
        ent_list = Dict{RegRef, RegRef}()

        swapcircuit = EntanglementSwap(p.ϵ_g, p.ξ, rng)
        purifycircuit = DEJMPSProtocol(p.ϵ_g, p.ξ)

        new(p, rng, 0.0, nodes, ent_list, swapcircuit, purifycircuit)
    end
end


include("./utils/bellStates.jl")
include("./utils/network.jl")
include("./utils/distil_sched.jl")
include("./baseops/uptotime.jl")

include("./processes/purify.jl")
include("./processes/entangle.jl")
include("./processes/ent_swap.jl")


function simulate!(N::Network; PLOT::Bool=false)
    n = N.param.n
    plots::Vector{Figure} = []

    @info "Starting simulation of Quantum Network with n=$n"
    entangle!(N)
    
    if PLOT push!(plots, netplot(N)) end

    for i in Int64.(1:log2(n))
        if N.param.distil_sched[i]
            @info "Purifying at level $i"
            purify!(N)

            if PLOT push!(plots, netplot(N)) end
        end

        @info "Performing entanglement swapping at level $i"
        ent_swap!(N, i)

        if PLOT push!(plots, netplot(N)) end
    end
    
    if PLOT
        return plots
    end
end