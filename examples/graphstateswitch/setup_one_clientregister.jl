using QuantumSavory
using QuantumSavory.ProtocolZoo
using ConcurrentSim
using ResumableFunctions
using Distributions
using DataFrames
using CSV
using Profile
using NetworkLayout
import QuantumSymbolics: express, CliffordRepr

function order_state!(reg, orderlist)
    @assert length(reg) == length(orderlist)

    # Loop over each index i
    for i in 1:length(orderlist)
        # If the qubit at position i isn't i, swap it with wherever qubit i lives
        while orderlist[i] != i
            # Find which position holds the qubit i
            correct_index = findfirst(==(i), orderlist)

            # Swap the register qubits physically
            SWAP!(reg, correct_index, i)

            # Swap the entries in orderlist
            orderlist[i], orderlist[correct_index] = orderlist[correct_index], orderlist[i]
        end
    end
end

function SWAP!(reg, idx1, idx2)
    q1 = reg[idx1]
    q2 = reg[idx2]
    apply!((q1, q2), CNOT)
    apply!((q2, q1), CNOT)
    apply!((q1, q2), CNOT)
end

@resumable function PiecemakerProt(sim, net, nclients, node::Int, graphdata::Dict, graphstates::Dict, period::Float64=1.)
    checkset = collect(keys(graphdata)) # Set of cores to check for
    sanity_counter = 20 # Temporary sanity counter to avoid infinite loop
    past_qubits = Int[] # Qubits that have been entangled in the past
    measured_out_qubits = Int[] # Qubits that have been measured out
    coreslots = RegRef[] # Slots that are part of the chosen core
    no_core = true # Flag to check if core is found
    init_plot = true # Flag to plot graph only once
    d = Dict{RegRef,Int}() # Dictionary to map slots to clients

    while true

        qparticipating = queryall(net[node], EntanglementCounterpart, ❓, ❓; locked=false, assigned=true) 
        
        # Dict that maps the node slot (key) to the client (value). 
        # Multiple different slots can point to the same client, should they engage in entanglement generation again.
        for msg in qparticipating
            d[msg.slot] = msg.tag[3] # client indices start in network from 1: net[1][1] is client 1
            untag!(net[node], msg.id) # Untag the client
        end
        @info "Dictionary:", d
        pairs_array = collect(d)  # This is now a Vector of (key, value) pairs in insertion order
        @info "Active clients:", pairs_array 

        # if no_core
        #     idx1 = findfirst(x -> x[2] == 2, pairs_array)
        #     idx2 = findfirst(x -> x[2] == 4, pairs_array)

        #     if !isnothing(idx1) && !isnothing(idx2)
        #         append!(coreslots, [pairs_array[idx1][1], pairs_array[idx2][1]])
        #         no_core = false # Core is found!
        #     end
        # end

        if no_core # If no core has been found, check if a core is present; return first core that arises
            # core = Vector{Tuple{RegRef, RegRef}}() # maybe use later for multiple cores
            for t in checkset
                idx1 = findfirst(x -> x[2] == t[1], pairs_array)
                idx2 = findfirst(x -> x[2] == t[2], pairs_array)

                if !isnothing(idx1) && !isnothing(idx2)
                    append!(coreslots, [pairs_array[idx1][1], pairs_array[idx2][1]])
                    no_core = false # Core is found!
                    #push!(core, coreslots)
                    break # As soon as a core is found it is fixed
                end
            end
        end

        sanity_counter -= 1
        if sanity_counter == 0
            no_core = false
            @error "Could not find core after 20 iterations, exiting PiecemakerProt"
            break
        end


        if !no_core # If core is found, check which other qubits are present and measure them out
            
            # Determine the graph state associated with the found core
            graph = graphdata[Tuple([slot.idx for slot in coreslots])] #
            if init_plot
                g = viewgraph(graph)
                savefig(g, "examples/graphstateswitch/graph.png")
                init_plot = false
            end

            # Generate graph state in storage qubits
            for e in edges(graph)
                u, v = Tuple(e)
        
                slot1storage = net[node][nclients+u]
                slot2storage = net[node][nclients+v]
        
                @yield lock(slot1storage) & lock(slot2storage)
                apply!((slot1storage, slot2storage), ZCZ) # TODO: check if this is the correct CZ gate to apply
                unlock(slot1storage)
                unlock(slot2storage)
                rem_edge!(graph, e) # Remove edge from graph after applying CZ gate as CZ gate is applied only once
                @info "Applied CZ gate between qubits $(slot1storage.idx) and $(slot2storage.idx)"
            end

            # Get the non-core slots
            @info "Present slots:", d
            dnoncore = copy(d)
            for coreslot in coreslots
                delete!(dnoncore, coreslot)
            end
            @info "Non core slots:", dnoncore
            @info "Coreslots:", coreslots

            # # Initialize qubits in |+> that have not been initialized in the past
            # for v in vertices(graph)
            #     if !(v in past_qubits) 
            #         slot = net[node][v]
            #         storageslot = net[node][nclients+v]

            #         @yield lock(storageslot)
            #         @info "Initialize storage qubit $(storageslot.idx)"
            #         initialize!(storageslot, X1)
            #         unlock(storageslot)
            #         append!(past_qubits, v)

            #     end
            # end

            # Apply CZ gates according to graph between present qubits and measure out non-core qubits
            # for e in edges(graph)
            #     u, v = Tuple(e)
            #     slot1 = net[node][u]
            #     slot2 = net[node][v]

            #     slot1storage = net[node][nclients+u]
            #     slot2storage = net[node][nclients+v]

            #     if haskey(d, slot1) && haskey(d, slot2)
            #         @yield lock(slot1storage) & lock(slot2storage)
            #         apply!((slot1storage, slot2storage), ZCZ) # TODO: check if this is the correct CZ gate to apply
            #         unlock(slot1storage)
            #         unlock(slot2storage)
            #         rem_edge!(graph, e) # Remove edge from graph after applying CZ gate as CZ gate is applied only once
            #         @info "Applied CZ gate between qubits $(slot1storage.idx) and $(slot2storage.idx)"
            #     end
            # end

            for (slot, tag) in dnoncore
                storageslot = net[node][nclients+slot.idx]
                
                clientslot = net[1][slot.idx]
                @info "clientslot", clientslot.reg
                @yield lock(storageslot) & lock(slot) & lock(clientslot)

                apply!((storageslot, slot), CNOT)
                @info "Applied CNOT between qubits $(storageslot) and $(slot)"
                apply!(storageslot, H)
                @info "Applied H to qubit $(storageslot)"
            
                zmeas1 = project_traceout!(storageslot, σᶻ)
                zmeas2 = project_traceout!(slot, σᶻ)
            
                if zmeas2==2 apply!(clientslot, X) end
                if zmeas1==2 apply!(clientslot, Z) end

                # Tag(updategate, pastremotenode, pastremoteslotid, localslotid, newremotenode, newremoteslotid, correction)
                # msg = Tag(EntanglementUpdateZ, node, slot.idx, 1, node, storageslot.idx, zmeas) # TODO: use wildcard/zero instead of slot2.idx since there is multiple slots a client can be entangled optimizer_with_attributes
                # put!(channel(net, node=>tag; permit_forward=true), msg)
                # msg = Tag(EntanglementUpdateX, node, storageslot.idx, 1, node, 0, xmeas) # TODO: use wildcard/zero instead of slot2.idx since there is multiple slots a client can be entangled optimizer_with_attributes
                # put!(channel(net, node=>tag; permit_forward=true), msg)
                # @info "Measured and sent message to client $(d[slot])"
                accesstimes = copy(clientslot.reg.accesstimes)
                unlock(storageslot)
                unlock(slot)
                unlock(clientslot)
                delete!(d, slot)
                append!(measured_out_qubits, slot.idx)
            end


            # Measure out core qubits at last
            # @info "Past qubits:", past_qubits
            if length(measured_out_qubits) == length([range(1,nclients)...])-2
                @info "Measure out core qubits at last"
                for slot in coreslots
                    storageslot = net[node][nclients+slot.idx]
                    
                    clientslot = net[1][slot.idx]
                    @info "clientslot", clientslot
                    @yield lock(storageslot) & lock(slot) & lock(clientslot)

                    apply!((storageslot, slot), CNOT)
                    apply!(storageslot, H)
                
                    zmeas1 = project_traceout!(storageslot, σᶻ)
                    zmeas2 = project_traceout!(slot, σᶻ)
                
                    if zmeas2==2 apply!(clientslot, X) end
                    if zmeas1==2 apply!(clientslot, Z) end

                    # Tag(updategate, pastremotenode, pastremoteslotid, localslotid, newremotenode, newremoteslotid, correction)
                    # msg = Tag(EntanglementUpdateX, node, slot.idx, 1, node, storageslot.idx, xmeas) # TODO: use wildcard/zero instead of slot2.idx since there is multiple slots a client can be entangled optimizer_with_attributes
                    # put!(channel(net, node=>tag; permit_forward=true), msg)
                    # msg = Tag(EntanglementUpdateZ, node, storageslot.idx, 1, node, 0, zmeas) # TODO: use wildcard/zero instead of slot2.idx since there is multiple slots a client can be entangled optimizer_with_attributes
                    # put!(channel(net, node=>tag; permit_forward=true), msg)
                    # @info "Measured and sent message to client $(d[slot])"
                    unlock(storageslot)
                    unlock(slot)
                    unlock(clientslot)

                    append!(measured_out_qubits, slot.idx)
                end

                @assert all(isnothing(net[node][i].reg.staterefs[i]) for i in 1:nclients) "Not all switch slots are measured out!"  # Check if all qubits at the switch are measured out
                # Measure final graph state
                client_slots = [net[1][i] for i in 1:nclients]
                @info "order measured out", measured_out_qubits
                locks = []
                for slot in client_slots
                    push!(locks, lock(slot))
                end
                all_locks = reduce(&, locks)
                @yield all_locks # Wait for all locks to complete
                @info client_slots[1].reg.stateindices
                order_state!(client_slots, measured_out_qubits)
                @info net[2][1].reg.stateindices
                @info client_slots[1].reg.stateindices
                @info client_slots

                # for slot in client_slots
                #     r = slot.reg
                #     i = slot.idx
                #     ref = r.staterefs[i]
                #     @info "Register: $(r), Slot index: $(i), State Ref: $(ref)"
                #     if ref !== nothing
                #         @info "Underlying State:" ref.state[]
                #     else
                #         @info "No state found for this slot."
                #     end
                # end
                #@info graphstates[Tuple([slot.idx for slot in coreslots])]
                #@info client_slots[1].reg.staterefs[1].state[]
                fidelity =  dagger(client_slots[1].reg.staterefs[1].state[]) * graphstates[Tuple([slot.idx for slot in coreslots])]
                @info "Fidelity: ", fidelity
                
                for k in 1:nclients
                    unlock(net[1][k])
                end
                return  # All qubits are measured out stop the protocol
            end 
        end
        @yield timeout(sim, period)
    end
end

@resumable function entangle(sim, net, client, link_success_prob)

    # Set up the entangler protocols at each client
    entangler = EntanglerProt(
        sim=sim, net=net, nodeA=2, slotA=client, nodeB=1, slotB=client,
        success_prob=link_success_prob, rounds=1, attempts=-1, attempt_time=1.0 #pairstate=StabilizerState("XZ ZX") # Note: generate a two-graph state instead of a bell pair
        )
    @yield @process entangler()
    # start core checker protocol: checks in each cycle if core is present, 
    # as soon as core is found: measure out if client not part of present core, else keep
    # fuser = FusionProt(
    #         sim=sim, net=net, node=1,
    #         nodeC=client,
    #         rounds=1
    #     )
    # @yield @process fuser()
end


@resumable function run_protocols(sim, net, nclients, link_success_prob, graphdata, graphstates)
    
    # Set up the entanglement trackers at client register
    tracker = EntanglementTracker(sim, net, 1) 
    @process tracker()

    # Run PiecemakerProt for the switch
    switchnode_idx = 2
    @process PiecemakerProt(sim, net, nclients, switchnode_idx, graphdata, graphstates)

    # Run entangler for each client and wait for all to finish
    procs_succeeded = []
    for k in 1:nclients
        proc_succeeded = @process entangle(sim, net, k, link_success_prob)
        push!(procs_succeeded, proc_succeeded)
    end
    @yield reduce(&, procs_succeeded)

end

function prepare_simulation(nclients, graphdata, operations, graphstates; link_success_prob = 0.5)
    
    memory_qubits_switch = nclients # memory slots in switch is equal to the number of clients in this example

    # The graph of network connectivity.
    setup = star_graph(nclients+1)

    switch_register = Register(2*memory_qubits_switch) # 1x communication qubit and 1x memory qubit per client at the switch
    clients_register = Register(nclients)
    net = RegisterNet(setup, [clients_register, switch_register])
    sim = get_time_tracker(net)


    initialize!([net[2][i] for i in range(nclients+1,2*nclients)], reduce(⊗, [fill(X1,nclients)...])) # Initialize all qubits at the clients in the plus state

    # Initialize all qubits at the switch in the plus state 
    # -- either use comm qubits in addition to memory qubits or find out if possible to apply Hadamard to memory qubits after entanglement is generated
    #initialize!(net[1][1], X1; time=now(sim))
    
    # Run entangler and graph state generator
    @process run_protocols(sim, net, nclients, link_success_prob, graphdata, graphstates)

    # Set up the consumer to measure final entangled state
    # consumer = FusionConsumer(net, net[1][m]; period=0.001)
    # @process consumer()
    return sim#, consumer
end