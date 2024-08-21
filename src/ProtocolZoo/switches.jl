module Switches

using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo: EntanglementCounterpart, AbstractProtocol
using Graphs: edges, complete_graph, neighbors
#using GraphsMatching: maximum_weight_matching
using Combinatorics: combinations
#using JuMP: MOI, optimizer_with_attributes
#import Cbc
using DocStringExtensions: TYPEDEF, TYPEDFIELDS
using ConcurrentSim: @process, timeout, Simulation, Process
#using ResumableFunctions: @resumable, @yield # TODO serious bug that makes it not work without full `using`
using ResumableFunctions
using Random

export SimpleSwitchDiscreteProt, SwitchRequest

"""
A wrapper around a matrix, ensuring that it is symmetric.
We have our own because `LinearAlgebra.Symmetric` forbids arbitrary `setindex!` operations.
"""
struct SymMatrix{M}
    matrix::M
end
Base.setindex!(sm::SymMatrix, v, i, j) = setindex!(sm.matrix, v, minmax(i, j)...)
Base.getindex(sm::SymMatrix, i, j) = getindex(sm.matrix, minmax(i, j)...)
Base.sum(sm::SymMatrix) = sum(sm.matrix)

"""
One of the switch memory assignment algorithms in use by [`SimpleSwitchDiscreteProt`](@ref)
as proposed in [promponas2024maximizing](@cite).

- `M` the number of memory slots in the switch
- `N` the number of client nodes
- `backlog[i,j]` is the number of requests backlogged between client nodes `i` and `j`
- `eprobs[i]` is the probability of successful entanglement establishment between the switch and node i

Returns the best assignment of memory slots to client nodes (an array of length `M` with values in `1:N`).
Returns `nothing` if no assignment is possible or necessary.

```jldoctest
julia> let
           m = 4 # number of memory slots
           n = 5 # number of clients
           eprobs = zeros(n) # success probabilities for entangling with a client during a timeslot
           eprobs .= 0.6
           eprobs[3] = 0.9
           eprobs[4] = 0.8
           eprobs[5] = 0.7
           eprobs[2] = 0.5
           backlog = zeros(Int, n, n) # number of requests backlogged between client nodes
           for i in 1:n
               for j in 1:n
                   i == j && continue
                   backlog[i,j] = 10
               end
           end
           QuantumSavory.ProtocolZoo.Switches.promponas_bruteforce_choice(m,n,backlog,eprobs)
       end
4-element Vector{Int64}:
 1
 3
 4
 5
```
"""
function promponas_bruteforce_choice(M,N,backlog,eprobs) # TODO mark as public but unexported
    return randperm(N)[1:M]
    # best_weight = 0.0
    # best_assignment = zeros(Int, M)
    # graphs = [complete_graph(i) for i in 1:M] # preallocating them to avoid expensive allocations in the inner loop
    # weights = [zeros(Int, i, i) for i in 1:M] # preallocating them to avoid expensive allocations in the inner loop
    # found = false
    # for assigned_nodes in combinations(1:N, M)
    #     current_weight = 0.0
    #     for entangled_pattern in combinations(assigned_nodes)
    #         p = prod(@view eprobs[entangled_pattern])
    #         i = length(entangled_pattern)
    #         g = graphs[i]
    #         w = weights[i]
    #         (;weight, mate) = match_entangled_pattern(backlog, entangled_pattern, g, w)
    #         # TODO above, is this a good choice for optimizer
    #         # TODO above, can we preallocate model objects and optimizer objects to avoid allocations in the inner loop
    #         current_weight += weight*p
    #     end
    #     if current_weight > best_weight
    #         best_weight = current_weight
    #         best_assignment .= assigned_nodes
    #         found = true
    #     end
    # end
    # return found ? best_assignment : nothing
end

"""
Perform the match of clients in `entangled_nodes` based on matching weights from `backlog`.
`g` and `w` are just preallocated buffers.
`g` has to be a complete graph and `w` has to be an integer matrix (not necessarily uninitialized).

Returns the weight of the best matching and the list of pairs of matched nodes.
"""
function match_entangled_pattern(backlog, entangled_nodes, g, w)
    # w .= 0 # not needed because g is a complete graph
    for (;src, dst) in edges(g)
        w[src,dst] = backlog[entangled_nodes[src], entangled_nodes[dst]]
    end
    opt = optimizer_with_attributes(Cbc.Optimizer, "LogLevel" => 0, MOI.Silent() => true)
    match = capture_stdout() do; maximum_weight_matching(g,opt,w); end
    weight = match.weight
    mate = [(entangled_nodes[i],entangled_nodes[j]) for (i,j) in enumerate(match.mate) if i<j]
    return (;weight, mate)
end

"""Some of the external optimizers we use create a ton of junk console output. This function redirects stdout to hide the junk."""
function capture_stdout(f)
    # return f()
    stdout_orig = stdout
    flush(stdout)
    (rd, wr) = redirect_stdout()
    r = f()
    close(wr)
    redirect_stdout(stdout_orig)
    return r
end


"""
$TYPEDEF

A switch "controller", running on a given node, checking for connection requests
from neighboring clients, and attempting to serve them by attempting direct raw entanglement
with the clients and then mediating swaps to connect two clients together.

Works on discrete time intervals and destroys raw entanglement not used by the end of a ticktock cycle.

This switch is mostly based on the architecture proposed in [promponas2024maximizing](@cite).
Multiple switch management algorithms are suggested in that paper.
By default we use the `QuantumSavory.ProtocolZoo.Switches.promponas_bruteforce_choice` algorithm.

$TYPEDFIELDS
"""
@kwdef struct SimpleSwitchDiscreteProt{AA} <: AbstractProtocol where {AA}
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation # TODO check that
    """a network graph of registers"""
    net::RegisterNet
    """the vertex index of the switch"""
    switchnode::Int
    """the vertex indices of the clients"""
    clientnodes::Vector{Int}
    """best-guess about success of establishing raw entanglement between client and switch"""
    success_probs::Vector{Float64}
    """duration of a single full cycle of the switching decision algorithm"""
    ticktock::Float64 = 1
    """how many rounds of this protocol to run (`-1` for infinite)"""
    rounds::Int = -1
    """the algorithm to use for memory slot assignment, defaulting to `promponas_bruteforce_choice`"""
    assignment_algorithm::AA = promponas_bruteforce_choice
    backlog::SymMatrix{Matrix{Int}}
    function SimpleSwitchDiscreteProt(sim, net, switchnode, clientnodes, success_probs, ticktock, rounds, assignment_algorithm, backlog)
        length(unique(clientnodes)) == length(clientnodes) || throw(ArgumentError("In the preparation of `SimpleSwitchDiscreteProt` switch protocol, the requested `clientnodes` must be unique!"))
        all(in(neighbors(net, switchnode)), clientnodes) || throw(ArgumentError("In the preparation of `SimpleSwitchDiscreteProt` switch protocol, the requested `clientnodes` must be directly connected to the `switchnode`!"))
        0 < ticktock || throw(ArgumentError("In the preparation of `SimpleSwitchDiscreteProt` switch protocol, the requested protocol period `ticktock` must be positive!"))
        0 < rounds || rounds == -1 || throw(ArgumentError("In the preparation of `SimpleSwitchDiscreteProt` switch protocol, the requested number of rounds `rounds` must be positive or `-1` for infinite!"))
        length(clientnodes) == length(success_probs) || throw(ArgumentError("In the preparation of `SimpleSwitchDiscreteProt` switch protocol, the requested `success_probs` must have the same length as `clientnodes`!"))
        all(0 .<= success_probs .<= 1) || throw(ArgumentError("In the preparation of `SimpleSwitchDiscreteProt` switch protocol, the requested `success_probs` must be in the range [0,1]!"))
        new{typeof(assignment_algorithm)}(sim, net, switchnode, clientnodes, success_probs, ticktock, rounds, assignment_algorithm, backlog)
    end
end

function SimpleSwitchDiscreteProt(sim, net, switchnode, clientnodes, success_probs; kwrags...)
    n = length(clientnodes)
    backlog = SymMatrix(zeros(Int, n, n))
    SimpleSwitchDiscreteProt(;sim, net, switchnode, clientnodes=collect(clientnodes), success_probs=collect(success_probs), backlog, kwrags...)
end
SimpleSwitchDiscreteProt(net, switchnode, clientnodes, success_probs; kwrags...) = SimpleSwitchDiscreteProt(get_time_tracker(net), net, switchnode, clientnodes, success_probs; kwrags...)

@resumable function (prot::SimpleSwitchDiscreteProt)()
    rounds = prot.rounds
    round = 1
    net = prot.net
    clientnodes = prot.clientnodes
    switchnode = prot.switchnode
    backlog = prot.backlog
    n = length(clientnodes)
    m = nsubsystems(net[switchnode])
    reverseclientindex = Dict{Int,Int}(c=>i for (i,c) in enumerate(clientnodes))

    # start a process to delete unused switch-to-node entanglement at the end of each round
    deleter = _SwitchSynchronizedDelete(prot)
    @process deleter()

    while rounds != 0
        rounds==-1 || (rounds -= 1)

        # read the backlog into a weight matrix
        _switch_read_backlog(prot, reverseclientindex)

        # pick a set of client nodes to which to assign local memory slots
        if prot.assignment_algorithm == promponas_bruteforce_choice
            assignment = prot.assignment_algorithm(m,n,backlog,prot.success_probs)
            if isnothing(assignment)
                @debug "Switch $switchnode found no useful memory slot assignments"
                @yield timeout(prot.sim, prot.ticktock) # TODO this is a pretty arbitrary value # TODO timeouts should work on prot and on net
                continue
            end
            @debug "Switch $switchnode assigns memory slots to clients $([prot.clientnodes[a] for a in assignment])"
            
            # run entangler
            _switch_entangler(prot, assignment)
        else
            # run entangler without requests (=no assignment)
            println("RUN WITH NO ASSIGNMENTS")
            _switch_entangler_all(prot)
        end
        @yield timeout(prot.sim, prot.ticktock/2) # TODO this is a pretty arbitrary value # TODO timeouts should work on prot and on net

        # read which entanglements were successful
        # and pick an optimal matching given the backlog of requests
        
        match = _switch_successful_entanglements_best_match(prot, reverseclientindex)
        #match = _switch_successful_entanglements(prot, reverseclientindex)
        if isnothing(match)
            @yield timeout(prot.sim, prot.ticktock/2) # TODO this is a pretty arbitrary value # TODO timeouts should work on prot and on net
            continue
        end

        # perform swaps
        _switch_run_swaps(prot, match)
        #_switch_run_fusions(prot, match)
        @yield timeout(prot.sim, prot.ticktock/2) # TODO this is a pretty arbitrary value # TODO timeouts should work on prot and on net
    end
end

"""
Private protocol used inside [`SimpleSwitchDiscreteProt`](@ref)
to delete unused entanglement at the end of each round.
"""
struct _SwitchSynchronizedDelete <: AbstractProtocol
    prot::SimpleSwitchDiscreteProt
end
QuantumSavory.get_time_tracker(deleter::_SwitchSynchronizedDelete) = get_time_tracker(deleter.prot)
@resumable function (deleter::_SwitchSynchronizedDelete)()
    prot = deleter.prot
    @yield timeout(prot.sim, eps(prot.ticktock)) # offset the start of the process infinitesimally
    while true
        @yield timeout(prot.sim, prot.ticktock)
        while true
            res = query(prot.net[prot.switchnode], EntanglementCounterpart, in(prot.clientnodes), ❓)
            isnothing(res) && break
            switchslot = res.slot.idx
            clientnode = res.tag[2]
            clientslot = res.tag[3]
            @debug "Switch $(prot.switchnode).$(switchslot) deletes unused entanglement with client $(clientnode).$(clientslot)"
            traceout!(res.slot, prot.net[clientnode][clientslot])
            untag!(res.slot, res.id)
            res = query(prot.net[clientnode][clientslot], EntanglementCounterpart, prot.switchnode, switchslot)
            untag!(prot.net[clientnode][clientslot], res.id)
        end
    end
end

"""
Read the backlog of requests from the switch's message buffer
and increment the corresponding entries in the `backlog` matrix.
"""
function _switch_read_backlog(prot, reverseclientindex)
    while true
        switchrequest = querydelete!(messagebuffer(prot.net[prot.switchnode]), SwitchRequest, ❓, ❓)
        isnothing(switchrequest) && break
        tag = switchrequest.tag
        i = reverseclientindex[tag[2]]
        j = reverseclientindex[tag[3]]
        prot.backlog[i,j] += 1
    end
end

"""
Run the entangler protocol between the switch and each client (no assignment).
"""
function _switch_entangler_all(prot)
    @assert length(prot.clientnodes) == nsubsystems(prot.net[prot.switchnode])-1 "Number of clientnodes needs to equal the number of switch registers."
    for (id, client) in enumerate(prot.clientnodes) 
        entangler = EntanglerProt(
            sim=prot.sim, net=prot.net,
            nodeA=prot.switchnode, nodeB=client,
            rounds=1, attempts=1, success_prob=prot.success_probs[id],
            attempt_time=prot.ticktock/10 # TODO this is a pretty arbitrary value
        )
        @process entangler()
    end
end

"""
Run the entangler protocol between the switch and each client in the assignment.
"""
function _switch_entangler(prot, assignment)
    # TODO make the entangler independent and just make requests to it
    for client_assignmentid in assignment
        client = prot.clientnodes[client_assignmentid]
        entangler = EntanglerProt(
            sim=prot.sim, net=prot.net,
            nodeA=prot.switchnode, nodeB=client,
            rounds=1, attempts=1, success_prob=prot.success_probs[client_assignmentid],
            attempt_time=prot.ticktock/10 # TODO this is a pretty arbitrary value
        )
        @process entangler()
    end
end

"""
Run `queryall(switch, EntanglemetnCounterpart, ...)`
to find out which clients the switch has successfully entangled with.
Then, choose a matching of entangled clients to the memory slots of the switch,
and return the best match given the current backlog of requests.
"""
function _switch_successful_entanglements_best_match(prot, reverseclientindex)
    switch = prot.net[prot.switchnode]
    successes = queryall(switch, EntanglementCounterpart, in(prot.clientnodes), ❓)
    entangled_clients = [r.tag[2] for r in successes]
    if isempty(entangled_clients)
        @debug "Switch $(prot.switchnode) failed to entangle with any clients"
        return nothing
    end
    # get the maximum match for the actually connected nodes
    ne = length(entangled_clients)
    if ne < 2 return nothing end
    entangled_clients_revindex = [reverseclientindex[k] for k in entangled_clients]
    @debug "Switch $(prot.switchnode) successfully entangled with clients $entangled_clients" # (indexed as $entangled_clients_revindex)"
    # (;weight, mate) = match_entangled_pattern(prot.backlog, entangled_clients_revindex, complete_graph(ne), zeros(Int, ne, ne))
    mate = collect(zip(entangled_clients_revindex[1:2:end], entangled_clients_revindex[2:2:end]))
    isempty(mate) && return nothing
    # @show mate
    return mate
end

function _switch_successful_entanglements(prot, reverseclientindex)
    switch = prot.net[prot.switchnode]
    successes = queryall(switch, EntanglementCounterpart, in(prot.clientnodes), ❓)
    entangled_clients = [r.tag[2] for r in successes]
    if isempty(entangled_clients)
        @debug "Switch $(prot.switchnode) failed to entangle with any clients"
        return nothing
    end
    # get the maximum match for the actually connected nodes
    ne = length(entangled_clients)
    if ne < 1 return nothing end
    entangled_clients_revindex = [reverseclientindex[k] for k in entangled_clients]
    @debug "Switch $(prot.switchnode) successfully entangled with clients $entangled_clients" 
    return entangled_clients_revindex
end

"""
Assuming the pairs in `match` are entangled,
perform swaps to connect them and decrement the backlog counter.
"""
function _switch_run_swaps(prot, match)
    #@info "Switch $(prot.switchnode) performs swaps for client pairs $([(prot.clientnodes[i], prot.clientnodes[j]) for (i,j) in match])"
    for (i,j) in match
        swapper = SwapperProt( # TODO be more careful about how much simulated time this takes
            sim=prot.sim, net=prot.net, node=prot.switchnode,
            nodeL=prot.clientnodes[i], nodeH=prot.clientnodes[j],
            rounds=1
        )
        prot.backlog[i,j] -= 1
        @process swapper()
    end
end

"""
Assuming the clientnodes are entangled,
perform fusion to connect them with piecemaker qubit (no backlog discounter yet!).
"""
function _switch_run_fusions(prot, match)
    @info "Switch $(prot.switchnode) performs fusions for client $([i in match])"
    for i in match
        fusion = FusionProt( # TODO be more careful about how much simulated time this takes
            sim=prot.sim, net=prot.net, node=prot.switchnode,
            nodeC=prot.clientnodes[i],
            rounds=1
        )
        @process fusion()
    end
end


"""
$TYPEDEF

Notify a switch that you request to be entangled with another node.

$TYPEDFIELDS
"""
@kwdef struct SwitchRequest
    "the id of the node making the request"
    requester::Int
    "the id of the remote node to which we want to be entangled"
    remote_node::Int
end
Base.show(io::IO, tag::SwitchRequest) = print(io, "Request from $(tag.requester) to be entangled to $(tag.remote_node)")
QuantumSavory.Tag(tag::SwitchRequest) = Tag(SwitchRequest, tag.requester, tag.remote_node)


end # module
