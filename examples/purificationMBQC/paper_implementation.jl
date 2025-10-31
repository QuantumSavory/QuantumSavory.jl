using QuantumClifford.ECC: CSS, parity_checks
using QuantumClifford: stab_to_gf2, graphstate, Stabilizer, MixedDestabilizer, single_x, single_z, logicalxview, logicalzview

# after the paper
# TODO make separate nicely documented tests following the style of a very descriptive readme with links to online demos (have online demos)
# TODO Move to a submodule under ProtocolZoo called MBQCEntanglementDistillation, have documentation for that module and export only from that module but not from the parent module
# TODO check whether you are happy with the order of fields in the constructors of the structs
# TODO change all prints to @info messages formatted in the new style and generally make the logs better
# TODO add data in a _log field and show methods in the new style
# TODO make sure it runs as part of the tests and it is quiet (no annoying logs in the tests)

using ResumableFunctions
using ConcurrentSim
using Revise
using Graphs
using QuantumSavory
using QuantumSavory.ProtocolZoo
import QuantumSavory: Tag, swap!

include("../graphstate/graph_preparer.jl")

# implementing "Measurement-Based Entanglement Distillation and Constant-Rate Quantum Repeaters over Arbitrary Distances"

"""
\$TYPEDEF

Apply local operations to a graph state to convert it to a locally-equivalent general stabilizer state.

It is parameterized by the indices of the Hadamard, inverse Phase, and Z gates that need to be performed,
e.g. as provided by the `graphstate` function in QuantumClifford.jl.

There are constraints to how this protocol works, chiefly it is an "instant classical communication" protocol.
It is useful in situations where all "registers" or "nodes" are in the same fridge, controlled by a single controller.

Used in particular for MBQC Entanglement Distillation as presented in [yu_todo](@cite) as implemented in the module [MBQCEntanglementDistillation](@ref).

\$TYPEDFIELDS
"""
@kwdef struct GraphToResource <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """nodes at which the graph state is distributed"""
    nodes::Vector{Int}
    """slot at each node where the graph state qubit is stored"""
    slot::Int
    """indices where Hadamard corrections are to be applied"""
    hadamard_idx::Vector{Int}
    """indices where inverse Phase corrections are to be applied"""
    iphase_idx::Vector{Int}
    """indices where Z corrections are to be applied"""
    flips_idx::Vector{Int}
end

@resumable function (prot::GraphToResource)()
    (;sim, net, nodes, slot, hadamard_idx, iphase_idx, flips_idx) = prot

    for i in flips_idx
        error("`GraphToResource` does not support non-CSS codes as resources states yet -- Z flips are not available")
        #apply!(net[nodes[i]][slot], Z)
    end

    for i in iphase_idx
        error("`GraphToResource` does not support non-CSS codes as resources states yet -- inverse Phases are not available")
        #apply!(net[nodes[i]][slot], InvPhase)
    end

    for i in hadamard_idx
        apply!(net[nodes[i]][slot], H)
    end
end
@kwdef struct PurifierBellMeasurementResults
    node::Int
    measurements_XX::Int64
    measurements_ZZ::Int64
end
Base.show(io::IO, msg::PurifierBellMeasurementResults) = print(io, "XX and ZZ measurements for register $(msg.node): XX=$(bitstring(msg.measurements_XX)), ZZ=$(bitstring(msg.measurements_ZZ))")
Tag(msg::PurifierBellMeasurementResults) = Tag(PurifierBellMeasurementResults, msg.node, msg.measurements_XX, msg.measurements_ZZ)

"""
\$TYPEDEF

Apply Bell measurements to a number of local nodes, bitpack the results in a single `Int64` and send that information to a remote location.

There are constraints to how this protocol works, chiefly it is an "instant classical communication" protocol.
It is useful in situations where all "registers" or "nodes" are in the same fridge, controlled by a single controller.

Used in particular for MBQC Entanglement Distillation as presented in [yu_todo](@cite) as implemented in the module [MBQCEntanglementDistillation](@ref).

\$TYPEDFIELDS
"""
@kwdef struct PurifierBellMeasurements <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """nodes at which the Bell measurements will be happening"""
    nodes::Vector{Int}
    """"Chief" node for our local set of nodes, the source of the bitpacked message"""
    local_chief_idx::Int
    """"Chief" node for the remote set of nodes, the destination node for the bitpacked message"""
    remote_chief_idx::Int
    """One of the slot on which the Bell measurement is performed (same for all nodes). The control of the CNOT, measured in the X basis."""
    x_slot::Int
    """One of the slot on which the Bell measurement is performed (same for all nodes). The target of the CNOT, measured in the Z basis. """
    z_slot::Int
end

@resumable function (prot::PurifierBellMeasurements)()
    (;sim, net, nodes, local_chief_idx, remote_chief_idx, x_slot, z_slot) = prot

    n = length(nodes)

    slots = []
    for i in 1:n
        push!(slots, net[nodes[i]][x_slot])
        push!(slots, net[nodes[i]][z_slot])
    end

    @yield reduce(&, [lock(slot) for slot in slots])

    s = []

    t = []
    for i in 1:n
        _x_slot = net[nodes[i]][x_slot]
        _z_slot = net[nodes[i]][z_slot]

        apply!((_x_slot, _z_slot), CNOT)
        mX = project_traceout!(_x_slot, X)
        mZ = project_traceout!(_z_slot, Z)

        push!(s, mX - 1)  # Convert from {1,2} to {0,1}
        push!(t, mZ - 1)
    end

    for slot in slots
        unlock(slot)
    end

    s_int = sum(bit * 2^(i-1) for (i, bit) in enumerate(s))
    t_int = sum(bit * 2^(i-1) for (i, bit) in enumerate(t))

    msg = PurifierBellMeasurementResults(node=local_chief_idx, measurements_XX=s_int, measurements_ZZ=t_int)
    println(msg)

    tag!(net[local_chief_idx][storage_slot], Tag(msg))
    put!(channel(net, local_chief_idx=>remote_chief_idx; permit_forward=true), msg)
end

@kwdef struct PurifiedEntalgementCounterpart
    remote_node::Int
    remote_slot::Int
end
Base.show(io::IO, tag::PurifiedEntalgementCounterpart) = print(io, "Entangled to $(tag.remote_node).$(tag.remote_slot) (after purification)")
Tag(tag::PurifiedEntalgementCounterpart) = Tag(PurifiedEntalgementCounterpart, tag.remote_node, tag.remote_slot)

"""
\$TYPEDEF

Track results of Bell measurements sent from other locations, deciding how to proceed. The two options are:

- success in which case we tag the purified Bell pairs with `PurifiedEntanglementCounterpart` tag
- failure in which case we clean up all involved qubit slots

Used in particular for MBQC Entanglement Distillation as presented in [yu_todo](@cite) as implemented in the module [MBQCEntanglementDistillation](@ref).

\$TYPEDFIELDS
"""
@kwdef struct MBQCPurificationTracker <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """nodes storing the resource state -- first `n` correspond to initial Bell pairs, and last `k` correspond to purified Bell pairs, for a total of `n+k` nodes"""
    nodes::Vector{Int}
    """number of initial Bell pairs"""
    n::Int
    """"Chief" node for our local set of nodes, the source of the bitpacked message"""
    local_chief_idx::Int
    """"Chief" node for the remote set of nodes, the destination node for the bitpacked message"""
    remote_chief_idx::Int
    # TODO maybe we should just provide the code
    H1::Matrix{Int}
    H2::Matrix{Int}
    logxs::Stabilizer
    logzs::Stabilizer
    """where entanglement can be estabilished, e.g. the electron spin of a color center -- used to prepare the resource state, but afterwards it is where the long-range entanglement is established"""
    communication_slot::Int
    """where long-term storage is done, e.g. the nuclear spin of a color center -- where the resource state is put"""
    storage_slot::Int
    """whether to perform correction operations after receiving measurement messages from the remote location -- typically only one of the locations needs to perform correction operations, while both locations need to know whether to clean up after a failed purification"""
    correct::Bool = false
end

@resumable function (prot::MBQCPurificationTracker)()
    (;sim, net, nodes, n, local_chief_idx, remote_chief_idx, H1, H2, logxs, logzs, communication_slot, storage_slot, correct) = prot

    k = length(nodes) - n
    mb = messagebuffer(net, local_chief_idx)

    while true
        # Wait for local measurement result
        local_tag = query(net[local_chief_idx][storage_slot], PurifierBellMeasurementResults, local_chief_idx, ❓, ❓)

        if isnothing(local_tag)
            @yield onchange_tag(net[local_chief_idx][storage_slot])
            continue
        end

        # Wait for remote measurement result
        msg = query(mb, PurifierBellMeasurementResults, remote_chief_idx, ❓, ❓)
        if isnothing(msg)
            println("Starting message wait at $(now(sim)) with MessageBuffer containing: $(mb.buffer)")
            @yield wait(mb)
            println("Done waiting for message at $(local_chief_idx)")
            continue
        end

        msg_data = querydelete!(mb, PurifierBellMeasurementResults, ❓, ❓, ❓)
        local_measurements_XX = local_tag.tag.data[3]
        local_measurements_ZZ = local_tag.tag.data[4]
        _, (_, remote_node, remote_measurements_XX, remote_measurements_ZZ) = msg_data

        s_int = xor(local_measurements_XX, remote_measurements_XX)
        t_int = xor(local_measurements_ZZ, remote_measurements_ZZ)

        s = [((s_int >> (i-1)) & 1) for i in 1:n]
        t = [((t_int >> (i-1)) & 1) for i in 1:n]
        syndrome = (H1*s + H2*t) .% 2

        if syndrome == [0, 0]
            println("Purification was successful at time $(now(sim))")

            if correct
                println("Correction starting at $(now(sim))")

                logxs_binary = stab_to_gf2(logxs)
                logzs_binary = stab_to_gf2(logzs)
                X_1 = logxs_binary[:, 1:n]
                X_2 = logxs_binary[:, n+1:end]
                Z_1 = logzs_binary[:, 1:n]
                Z_2 = logzs_binary[:, n+1:end]

                # these dont work?
                # r_b = [sum(Z1[i,j] * Z2[i,j] for j in 1:n) for i in 1:k] .% 2
                # r_p = [sum(X1[i,j] * X2[i,j] for j in 1:n) for i in 1:k] .% 2
                r_b = (sum(Z_1 .* Z_2, dims=2)[:]) .% 2
                r_p = (sum(X_1 .* X_2, dims=2)[:]) .% 2

                β = (Z_1*s + Z_2*t + r_b) .% 2
                φ = (X_1*s + X_2*t + r_p) .% 2

                for i in 1:k
                    if β[i] == 1
                        apply!(net[nodes[n + i]][storage_slot], X)
                    end
                    if φ[i] == 1
                        apply!(net[nodes[n + i]][storage_slot], Z)
                    end
                end

                println("Correction completed at $(now(sim))")
            end

            # Tag purified pairs
            for i in n:n+k-1 # this assumes certain things, so maybe it can be refactored
                tag!(net[local_chief_idx + i][storage_slot], PurifiedEntalgementCounterpart, remote_chief_idx + i, storage_slot)
            end
        else
            println("Purification failed at time $(now(sim)). Syndrome: $syndrome")
            untag!(local_tag.slot, local_tag.id)
            for i in nodes
                traceout!(net[i][communication_slot])
                traceout!(net[i][storage_slot])
            end
        end
    end
end



@resumable function run_protocols(sim, net, n, resource_state, alice_nodes, bob_nodes, communication_slot, storage_slot, pairstate, H1, H2, logxs, logzs; rounds=-1)
    @assert n <= 63 "Number of (n=$n) exceeds maximum of 63 bits for Int64 encoding"
    k = length(alice_nodes) - n
    alice_chief_idx = alice_nodes[1]
    bob_chief_idx = bob_nodes[1]

    g, hadamard_idx, iphase_idx, flips_idx = graphstate(resource_state)

    graphA = GraphStateConstructor(sim, net, g, alice_nodes, communication_slot, storage_slot)
    graphB = GraphStateConstructor(sim, net, g, bob_nodes, communication_slot, storage_slot)
    resourceA = GraphToResource(sim, net, alice_nodes, storage_slot, hadamard_idx, iphase_idx, flips_idx)
    resourceB = GraphToResource(sim, net, bob_nodes, storage_slot, hadamard_idx, iphase_idx, flips_idx)
    alice_bell_meas = PurifierBellMeasurements(sim, net, collect(alice_nodes[1:n]), alice_chief_idx, bob_chief_idx, storage_slot, communication_slot)
    bob_bell_meas = PurifierBellMeasurements(sim, net, collect(bob_nodes[1:n]), bob_chief_idx, alice_chief_idx, storage_slot, communication_slot)
    alice_tracker = MBQCPurificationTracker(sim, net, alice_nodes, n, alice_chief_idx, bob_chief_idx, H1, H2, logxs, logzs, communication_slot, storage_slot, false)
    bob_tracker = MBQCPurificationTracker(sim, net, bob_nodes, n, bob_chief_idx, alice_chief_idx, H1, H2, logxs, logzs, communication_slot, storage_slot, true)
    @process alice_tracker()
    @process bob_tracker()
    # # consumer
    # for i in 1:k
    #     purified_consumer = EntanglementConsumer(sim, net, alice_nodes[n+i], bob_nodes[n+i]; tag=PurifiedEntalgementCounterpart)
    #     @process purified_consumer()
    # end

    round = 0
    while rounds == -1 || round < rounds
        round += 1
        g1 = @process graphA()
        g2 = @process graphB()
        @yield g1 & g2
        println("graph state ", now(sim))
        @yield timeout(sim, 10)


        r1 = @process resourceA()
        r2 = @process resourceB()
        entanglers = []
        for i in 1:n
            entangler = EntanglerProt(sim, net, alice_nodes[i], bob_nodes[i]; pairstate=pairstate, chooseA=communication_slot, chooseB=communication_slot, success_prob=1.0, attempts=-1, rounds=1) # TODO: change parameters
            e = @process entangler()
            push!(entanglers, e)
        end
        @yield reduce(&, (entanglers..., r1, r2))

        println("resource & entangle ", now(sim))
        @yield timeout(sim, 10)

        m1 = @process alice_bell_meas()
        m2 = @process bob_bell_meas()
        @yield m1 & m2

        println("measurements ", now(sim))
        @yield timeout(sim, 10)

        # for testing
        for i in 1:k
            purified_consumer = EntanglementConsumer(sim, net, alice_nodes[n+i], bob_nodes[n+i]; tag=PurifiedEntalgementCounterpart)
            @process purified_consumer()
        end
    end
end

function noisy_pair_func(perfect_pair, F)
    p = (4*F-1)/3
    perfect_pair_dm = SProjector(perfect_pair)
    mixed_dm = MixedState(perfect_pair_dm)
    return  p*perfect_pair_dm + (1-p)*mixed_dm
end

h1 = [1 1 1 1]
h2 = [1 1 1 1]
code = parity_checks(CSS(h1, h2)) # == S"XXXX ZZZZ"
c, n = size(code)
k = n - c
code_binary = stab_to_gf2(code)
H1 = code_binary[:, 1:n]
H2 = code_binary[:, n+1:end]
code_md = MixedDestabilizer(code)
logxs = logicalxview(code_md)
logzs = logicalzview(code_md)

# equation 1
resource_state = vcat(
    hcat(code, zero(Stabilizer, c, k)),
    Stabilizer([l⊗single_x(k,i) for (i,l) in enumerate(logxs)]),
    Stabilizer([l⊗single_z(k,i) for (i,l) in enumerate(logzs)]),
)

perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
pairstate = noisy_pair_func(perfect_pair, 0.9)
communication_slot = 1
storage_slot = 2
alice_nodes = 1:n+k
bob_nodes = n+k+1:2*(n+k)


registers = [Register(2) for _ in 1:2*(n+k)]
net = RegisterNet(registers)
sim = get_time_tracker(net)

@process run_protocols(sim, net, n, resource_state, alice_nodes, bob_nodes, communication_slot, storage_slot, pairstate, H1, H2, logxs, logzs, rounds=1)

run(sim, 5)

## graph state checks

g, hadamard_idx, iphase_idx, flips_idx = graphstate(resource_state)
# Alice's graph state
alice_regs = [net[i][storage_slot] for i in alice_nodes]
for i in 1:nv(g)
    println(observable(alice_regs, QuantumOpticsBase.Operator(QuantumClifford.Stabilizer(g)[i])))
end

# Bob's graph state
bob_regs = [net[i][storage_slot] for i in bob_nodes]
for i in 1:nv(g)
    println(observable(bob_regs, QuantumOpticsBase.Operator(QuantumClifford.Stabilizer(g)[i])))
end

## entangler checks - should be all nothing
for i in 1:n
    println(observable([net[alice_nodes[i]], net[bob_nodes[i]]], [communication_slot, communication_slot], projector(perfect_pair)))
end

run(sim, 15)

## resource state cheks

# Alice's resource state
for i in 1:length(resource_state)
    println(observable(alice_regs, QuantumOpticsBase.Operator(resource_state[i])))
end

# Bob's resource state
for i in 1:length(resource_state)
    println(observable(bob_regs, QuantumOpticsBase.Operator(resource_state[i])))
end

## entangler checks
for i in 1:n
    println(observable([net[alice_nodes[i]], net[bob_nodes[i]]], [communication_slot, communication_slot], projector(perfect_pair)))
end

run(sim, 25)

## purified entanglements checks
for i in 1:k
    println(query(net[alice_nodes[n+i]][storage_slot], PurifiedEntalgementCounterpart, ❓, ❓))
    println(query(net[bob_nodes[n+i]][storage_slot], PurifiedEntalgementCounterpart, ❓, ❓))
    println(observable([net[alice_nodes[n+i]], net[bob_nodes[n+i]]], [storage_slot, storage_slot], projector(perfect_pair)))
end


run(sim, 40)

## consumer check -  should be nothing
for i in 1:k
    println(query(net[alice_nodes[n+i]][storage_slot], PurifiedEntalgementCounterpart, ❓, ❓))
    println(query(net[bob_nodes[n+i]][storage_slot], PurifiedEntalgementCounterpart, ❓, ❓))
    println(observable([net[alice_nodes[n+i]], net[bob_nodes[n+i]]], [storage_slot, storage_slot], projector(perfect_pair)))
end



