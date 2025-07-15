using QuantumSavory
using QuantumSavory.ProtocolZoo
using Graphs
using ConcurrentSim
using ResumableFunctions
using Distributions
using DataFrames
using CSV
using Profile
using NetworkLayout


# """ $TYPEDEF

# ## Fields:

# $FIELDS

# A circuit that combines two multipartide entangled states (e.g., GHZ states) into one, up to some Pauli correction. 
# The circuit applies a CNOT gate, measures the target qubit in the Z basis and traces out the latter (removed from the register). 
# The measurement result (1 for |0⟩ and 2 for |1⟩) is returned by the circuit. 
# By measuring and discarding the target qubit, the entanglement is effectively transferred to the control qubit.

# This circuit is useful in protocols where two multipartide entangled states are combined into one, e.g., when generating graph states. 

# ```jldoctest
# julia> a = Register(1)
#        b = Register(2)
#        bell = (Z₁⊗Z₁+Z₂⊗Z₂)/√2
#        initialize!(a[1], X1)  # Initialize `a[1]` in |+⟩ state.
#        initialize!((b[1], b[2]), bell)  # Initialize `b` with a bell pair.

# julia> correction = EntanglementFusion()(a[1], b[1]) # Apply fusion and receive measurement outcome.

# julia> isassigned(b[1])  # The `b[1]` qubit has been traced out. 
# false

# julia> if correction==2 apply!(b[2], X) end # Apply correction.

# julia> real(observable((a[1], b[2]), projector(bell))) # Now bell pair is fused into a.
# 1.0
# ```
# """
# struct EntanglementFusion <: AbstractCircuit
# end

# function (::EntanglementFusion)(control,  target)
#     apply!((control, target), CNOT)
#     zmeas = project_traceout!(target, σᶻ)
#     zmeas
# end

# inputqubits(::EntanglementFusion) = 2


# """
# Run `queryall(switch, EntanglemetnCounterpart, ...)`
# to find out which clients the switch has successfully entangled with. 
# Then returns returns a list of indices corresponding to the successful clients.
# """

# function _switch_successful_entanglements(prot, reverseclientindex)
#     switch = prot.net[prot.switchnode]
#     successes = queryall(switch, EntanglementCounterpart, in(prot.clientnodes), ❓)
#     entangled_clients = [r.tag[2] for r in successes] # RegRef (qubit slot)
#     if isempty(entangled_clients)
#         @debug "Switch $(prot.switchnode) failed to entangle with any clients"
#         return nothing
#     end
#     # get the maximum match for the actually connected nodes
#     ne = length(entangled_clients)
#     @debug "Switch $(prot.switchnode) successfully entangled with $ne clients" 
#     if ne < 1 return nothing end
#     entangled_clients_revindex = [reverseclientindex[k] for k in entangled_clients]
#     return entangled_clients_revindex
# end

@resumable function init_state(sim, net, nclients::Int, delay::Real)
    @yield timeout(sim, delay)
    initialize!(net[1][nclients+1], X1; time=now(sim))
end

@resumable function entangle_and_fuse(sim, net, client, link_success_prob)

    # Set up the entanglement trackers at each client
    tracker = EntanglementTracker(sim, net, client) 
    @process tracker()

    # Set up the entangler and fuser protocols at each client
    entangler = EntanglerProt(
        sim=sim, net=net, nodeA=1, slotA=client-1, nodeB=client,
        success_prob=link_success_prob, rounds=1, attempts=-1, attempt_time=1.0 
        )
    @yield @process entangler()

    fuser = FusionProt(
            sim=sim, net=net, node=1,
            nodeC=client,
            rounds=1
        )
    @yield @process fuser()
end


@resumable function run_protocols(sim, net, nclients, link_success_prob)
    # Run entangler and fusion for each client and wait for all to finish
    procs_succeeded = []
    for k in 2:nclients+1    
        proc_succeeded = @process entangle_and_fuse(sim, net, k, link_success_prob)
        push!(procs_succeeded, proc_succeeded)
    end
    @yield reduce(&, procs_succeeded)
end

function prepare_simulation(nclients=2, mem_depolar_prob = 0.1, link_success_prob = 0.5)

    m = nclients+1 # memory slots in switch is equal to the number of clients + 1 slot for piecemaker qubit
    r_depol =  - log(1 - mem_depolar_prob) # depolarization rate
    delay = 1 # initialize the piecemaker |+> after one time unit (in order to provide fidelity ==1 if success probability = 1)

    # The graph of network connectivity. Index 1 corresponds to the switch.
    graph = star_graph(nclients+1)

    switch_register = Register(m, Depolarization(1/r_depol)) # the first slot is reserved for the 'piecemaker' qubit used as fusion qubit 
    client_registers = [Register(1, Depolarization(1/r_depol)) for _ in 1:nclients] #Depolarization(1/r_depol)
    net = RegisterNet(graph, [switch_register, client_registers...])
    sim = get_time_tracker(net)

    @process init_state(sim, net, nclients, delay)
    
    # Run entangler and fusion for each client and wait for all to finish
    @process run_protocols(sim, net, nclients, link_success_prob)

    # Set up the consumer to measure final entangled state
    consumer = FusionConsumer(net, net[1][m]; period=0.001)
    @process consumer()

    return sim, consumer
end


