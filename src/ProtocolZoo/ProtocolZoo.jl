module ProtocolZoo

using QuantumSavory
import QuantumSavory: get_time_tracker
using QuantumSavory: Wildcard
using QuantumSavory.CircuitZoo: EntanglementSwap
using DocStringExtensions

using Distributions: Geometric
using ConcurrentSim: Simulation, @yield, timeout, @process, now
import ConcurrentSim: Process
import ResumableFunctions
using ResumableFunctions: @resumable

export EntanglerProt, SwapperProt

abstract type AbstractProtocol end

get_time_tracker(prot::AbstractProtocol) = prot.sim

Process(prot::AbstractProtocol, args...; kwargs...) = Process((e,a...;k...)->prot(a...;k...,_prot=prot), get_time_tracker(prot), args...; kwargs...)

"""
$TYPEDEF

A protocol that generates entanglement between two nodes.
Whenever a pair of empty slots is available, the protocol locks them
and starts probabilistic attempts to establish entanglement.

$FIELDS
"""
@kwdef struct EntanglerProt{LT} <: AbstractProtocol where {LT<:Union{Float64,Nothing}}
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation # TODO check that
    """a network graph of registers"""
    net::RegisterNet
    """the vertex index of node A"""
    nodeA::Int
    """the vertex index of node B"""
    nodeB::Int
    """the state being generated (supports symbolic, numeric, noisy, and pure)"""
    pairstate = StabilizerState("ZZ XX")
    """success probability of one attempt of entanglement generation"""
    success_prob::Float64 = 0.001
    """duration of single entanglement attempt"""
    attempt_time::Float64 = 0.001
    """fixed "busy time" duration immediately before starting entanglement generation attempts"""
    local_busy_time_pre::Float64 = 0.0
    """fixed "busy time" duration immediately after the a successful entanglement generation attempt"""
    local_busy_time_post::Float64 = 0.0
    """how long to wait before retrying to lock qubits if no qubits are available (`nothing` for queuing up)"""
    retry_lock_time::LT = 0.1
    """how many rounds of this protocol to run (`-1` for infinite))"""
    rounds::Int = -1
end

"""Convenience constructor for specifying `rate` of generation instead of success probability and time"""
function EntanglerProt(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int; rate::Union{Nothing,Float64}=nothing, kwargs...)
    if isnothing(rate)
        return EntanglerProt(;sim, net, nodeA, nodeB, kwargs...)
    else
        return EntanglerProt(;sim, net, nodeA, nodeB, kwargs..., success_prob=0.001, attempt_time=0.001/rate)
    end
end

#TODO """Convenience constructor for specifying `fidelity` of generation instead of success probability and time"""

@resumable function (prot::EntanglerProt)(;_prot::EntanglerProt=prot)
    prot = _prot # weird workaround for no support for `struct A a::Int end; @resumable function (fa::A) return fa.a end`; see https://github.com/JuliaDynamics/ResumableFunctions.jl/issues/77
    rounds = prot.rounds
    while rounds != 0
        a = findfreeslot(prot.net[prot.nodeA])
        b = findfreeslot(prot.net[prot.nodeB])
        if isnothing(a) || isnothing(b)
            isnothing(prot.retry_lock_time) && error("we do not yet support waiting on register to make qubits available") # TODO
            @yield timeout(prot.sim, prot.retry_lock_time)
            continue
        end
        @yield lock(a) & lock(b) # this yield is expected to return immediately
        @yield timeout(prot.sim, prot.local_busy_time_pre)
        @yield timeout(prot.sim, (rand(Geometric(prot.success_prob))+1) * prot.attempt_time)
        initialize!((a,b), prot.pairstate; time=now(prot.sim))
        @yield timeout(prot.sim, prot.local_busy_time_post)
        tag!(a, :EntanglementCounterpart, prot.nodeB, b.idx)
        tag!(b, :EntanglementCounterpart, prot.nodeA, a.idx)
        unlock(a)
        unlock(b)
        rounds==-1 || (rounds -= 1)
    end
end


"""
$TYPEDEF

A protocol, running at a given node, that finds swappable entangled pairs and performs the swap.

$FIELDS
"""
@kwdef struct SwapperProt{L,R,LT} <: AbstractProtocol where {L<:Union{Int,<:Function,Wildcard}, R<:Union{Int,<:Function,Wildcard}, LT<:Union{Float64,Nothing}}
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex of the node where swapping is happening"""
    node::Int
    """the vertex of one of the remote nodes (or a predicate function or a wildcard)"""
    nodeL::L = ❓
    """the vertex of the other remote node (or a predicate function or a wildcard)"""
    nodeR::R = ❓
    """fixed "busy time" duration immediately before starting entanglement generation attempts"""
    local_busy_time::Float64 = 0.0 # TODO the gates should have that busy time built in
    """how long to wait before retrying to lock qubits if no qubits are available (`nothing` for queuing up and waiting)"""
    retry_lock_time::LT = 0.1
    """how many rounds of this protocol to run (`-1` for infinite))"""
    rounds::Int = -1
end

#TODO "convenience constructor for the missing things and finish this docstring"
function SwapperProt(sim::Simulation, net::RegisterNet, node::Int; kwargs...)
    return SwapperProt(;sim, net, node, kwargs...)
end

@resumable function (prot::SwapperProt)(;_prot::SwapperProt=prot)
    prot = _prot # weird workaround for no support for `struct A a::Int end; @resumable function (fa::A) return fa.a end`; see https://github.com/JuliaDynamics/ResumableFunctions.jl/issues/77
    rounds = prot.rounds
    while rounds != 0
        reg = prot.net[prot.node]
        qubit_pair = findswapablequbits(prot.net,prot.node)
        if isnothing(qubit_pair)
            isnothing(prot.retry_lock_time) && error("we do not yet support waiting on register to make qubits available") # TODO
            @yield timeout(prot.sim, prot.retry_lock_time)
            continue
        end
        (q1, tag1), (q2, tag2) = qubit_pair
        @yield lock(q1) & lock(q2) # this should not really need a yield thanks to `findswapablequbits`, but better defensive
        @yield timeout(prot.sim, prot.local_busy_time)
        untag!(q1, tag1)
        untag!(q2, tag2)
        uptotime!((q1, q2), now(prot.sim))
        # TODO
        # tell brother of q1 and brother of q2 to update their entanglement tags and send them the Pauli frame correction
        # do not magically update it as currently done here
        q1remote = prot.net[tag1[2]][tag1[3]]
        q2remote = prot.net[tag2[2]][tag2[3]]
        swapcircuit = EntanglementSwap()
        swapcircuit(q1, q1remote, q2, q2remote) # TODO no one is making sure that q1 and q2 were locked for this operation
        untag!(q1remote, Tag(:EntanglementCounterpart, prot.node, q1.idx))
        untag!(q2remote, Tag(:EntanglementCounterpart, prot.node, q2.idx))
        tag!(q1remote, tag1)
        tag!(q2remote, tag2)
        #
        unlock(q1)
        unlock(q2)
        rounds==-1 || (rounds -= 1)
    end
end

function findswapablequbits(net,node) # TODO parameterize the query predicates and the findmin/findmax
    reg = net[node]

    leftnodes  = queryall(reg, :EntanglementCounterpart, <(node), ❓; locked=false, assigned=true)
    rightnodes = queryall(reg, :EntanglementCounterpart, >(node), ❓; locked=false, assigned=true)

    (isempty(leftnodes) || isempty(rightnodes)) && return nothing
    _, il = findmin(n->n.tag[2], leftnodes)   # TODO make [2] into a nice named property
    _, ir = findmax(n->n.tag[2], rightnodes)
    return leftnodes[il], rightnodes[ir]
end


end # module
