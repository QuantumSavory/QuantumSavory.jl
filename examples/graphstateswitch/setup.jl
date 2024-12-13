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



@resumable function PiecemakerProt(sim, net, node::Int, checkset::Vector, graphdata::Dict, graphstates::Dict, period::Float64=1.)

    sanity_counter = 20 # Temporary sanity counter to avoid infinite loop
    past_qubits = Int[] # Qubits that have been entangled in the past
    coreslots = RegRef[] # Slots that are part of the chosen core
    no_core = true # Flag to check if core is found
    init_plot = true # Flag to plot graph only once
    
    while true
        # Checks which states are currently present at a node, can check for a specific set of nodes 
        qparticipating = queryall(net[node], EntanglementCounterpart, ❓, ❓; locked=false, assigned=true) 
        
        # Dict that maps the node slot (key) to the client (value). 
        # Multiple different slots can point to the same client, should they engage in entanglement generation again.
        d = Dict{RegRef,Int}()
        for q in qparticipating
            d[q.slot] = q.tag[2] # client indices start in network from 1: net[1] is client 1
        end
        
        pairs_array = collect(d)  # This is now a Vector of (key, value) pairs in insertion order
        @info "Active clients:", pairs_array 

        if no_core # If no core is found, check if a core is present; return first core that arises
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
            graph = graphdata[Tuple([slot.idx for slot in coreslots])]

            if init_plot
                g = viewgraph(graph)
                savefig(g, "examples/graphstateswitch/graph.png")
                init_plot = false
            end

            # Get the non-core slots
            #@info "Present slots:", d
            @info "Coreslots:", coreslots
            dnoncore = copy(d)
            for coreslot in coreslots
                delete!(dnoncore, coreslot)
            end
            @info "Non core slots:", dnoncore

            # Apply Hadamard gate to all qubits 
            for v in vertices(graph)
                if !(v in past_qubits) # Apply Hadamard gate only once
                    slot = net[node][v]
                    if haskey(d, slot)
                        @yield lock(slot)
                        # @info "Applying Hadamard gate to qubit $(slot.idx)"
                        # apply!(slot, H)
                        unlock(slot)
                        append!(past_qubits, slot.idx)
                    end
                end
            end

            # Apply CZ gates according to graph between present qubits and measure out non-core qubits
            for e in edges(graph)
                u, v = Tuple(e)
                slot1 = net[node][u]
                slot2 = net[node][v]

                if haskey(d, slot1) && haskey(d, slot2)
                    @yield lock(slot1) & lock(slot2)
                    apply!((slot1, slot2), ZCZ) # TODO: check if this is the correct CZ gate to apply
                    unlock(slot1)
                    unlock(slot2)
                    rem_edge!(graph, e) # Remove edge from graph after applying CZ gate as CZ gate is applied only once
                    @info "Applied CZ gate between qubits $(slot1.idx) and $(slot2.idx)"
                end
            end

            for (slot, tag) in dnoncore
                @yield lock(slot)
                zmeas = project_traceout!(slot, σᶻ) 

                # Tag(updategate, pastremotenode, pastremoteslotid, localslotid, newremotenode, newremoteslotid, correction)
                msg = Tag(EntanglementUpdateZ, node, slot.idx, 1, node, 0, zmeas) # TODO: use wildcard/zero instead of slot2.idx since there is multiple slots a client can be entangled optimizer_with_attributes
                put!(channel(net, node=>tag; permit_forward=true), msg)
                @info "Measured and sent message to client $(d[slot])"
                unlock(slot)
            end

            # Measure out core qubits at last
            # @info "Past qubits:", past_qubits
            if Set(past_qubits) == Set([range(1,nclients)...]) 
                @info "Measure out core qubits at last"
                for slot in coreslots
                    @yield lock(slot)
                    zmeas = project_traceout!(slot, σᶻ) 
                    msg = Tag(EntanglementUpdateZ, node, slot.idx, 1, node, 0, zmeas)
                    put!(channel(net, node=>d[slot]; permit_forward=true), msg)
                    @info "Measured and sent message to client $(d[slot])"
                    unlock(slot)
                end
                @yield timeout(sim, period)

                @assert all(isnothing(net[node][i].reg.staterefs[i]) for i in 1:nclients) "Not all switch slots are measured out!"  # Check if all qubits at the switch are measured out

            
                # Measure final graph state
                @yield timeout(sim, period)
                client_slots = [net[i][1] for i in 1:nclients]
                
                locks = []
                for slot in client_slots
                    push!(locks, lock(slot))
                end
                all_locks = reduce(&, locks)
                @yield all_locks # Wait for all locks to complete

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

                @info graphstates[Tuple([slot.idx for slot in coreslots])]
                @info client_slots[1].reg.staterefs[1].state[]
                fidelity =  dagger(client_slots[1].reg.staterefs[1].state[]) * graphstates[Tuple([slot.idx for slot in coreslots])]
                @info "Fidelity: ", fidelity
                
                for k in 1:nclients
                    unlock(net[k][1])
                end
                return  # All qubits are measured out stop the protocol
            end 
        end
        @yield timeout(sim, period)
    end
end

@resumable function entangle_and_fuse(sim, net, nclients, client, link_success_prob)

    # Set up the entanglement trackers at each client
    tracker = EntanglementTracker(sim, net, client) 
    @process tracker()

    # Set up the entangler and fuser protocols at each client
    entangler = EntanglerProt(
        sim=sim, net=net, nodeA=nclients+1, slotA=client, nodeB=client,
        success_prob=link_success_prob, rounds=1, attempts=-1, attempt_time=1.0, pairstate=StabilizerState("XZ ZX") # Note: generate a two-graph state instead of a bell pair
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


@resumable function run_protocols(sim, net, nclients, link_success_prob, checkset, graphdata, graphstates)
    
    # Run PiecemakerProt for the switch
    switchnode_idx = nclients+1
    @process PiecemakerProt(sim, net, switchnode_idx, checkset, graphdata, graphstates)

    # Run entangler and fusion for each client and wait for all to finish
    procs_succeeded = []
    for k in 1:nclients
        proc_succeeded = @process entangle_and_fuse(sim, net, nclients, k, link_success_prob)
        push!(procs_succeeded, proc_succeeded)
    end
    @yield reduce(&, procs_succeeded)

end

function prepare_simulation(nclients, graphdata, operaions, graphstates; link_success_prob = 0.5)
    cores = collect(keys(graphdata))
    current_core = cores[1]
    graph = graphdata[current_core]

    memory_qubits_switch = nclients # memory slots in switch is equal to the number of clients 

    # The graph of network connectivity. Index 1 corresponds to the switch.
    setup = star_graph(nclients+1)

    switch_register = Register(memory_qubits_switch)
    client_registers = [Register(1) for _ in 1:nclients] 
    net = RegisterNet(setup, [client_registers..., switch_register])
    sim = get_time_tracker(net)

    # Initialize all qubits at the switch in the plus state 
    # -- either use comm qubits in addition to memory qubits or find out if possible to apply Hadamard to memory qubits after entanglement is generated
    #initialize!(net[1][1], X1; time=now(sim))
    
    # Run entangler and fusion for each client and wait for all to finish
    @process run_protocols(sim, net, nclients, link_success_prob, cores, graphdata, graphstates)

    # Set up the consumer to measure final entangled state
    # consumer = FusionConsumer(net, net[1][m]; period=0.001)
    # @process consumer()
    return sim#, consumer
end


