# Shared setup for all QTCP tutorial scripts
#
# This file provides a `simulation_setup` function that creates a quantum network
# with the full QTCP protocol suite running on it. It works with any topology.

using QuantumSavory
using QuantumSavory.ProtocolZoo
using Graphs
using ConcurrentSim
using ResumableFunctions

"""
    simulation_setup(graph, regsize; kwargs...)

Set up a QTCP simulation on the given network topology.

# Arguments
- `graph`: a Graphs.jl graph describing the network topology
- `regsize`: number of qubit slots per node

# Keyword Arguments
- `T2=100.0`: T2 dephasing time for all qubits
- `representation=QuantumOpticsRepr`: quantum state representation
- `end_nodes=nothing`: which nodes run EndNodeController (default: all nodes)
- `EndNodeControllerType=EndNodeController`: allows replacing with a custom controller

# Returns
`(sim, net)` — the simulation scheduler and the register network.
"""
function simulation_setup(
    graph,
    regsize::Int;
    T2 = 100.0,
    representation = QuantumOpticsRepr,
    end_nodes = nothing,
    EndNodeControllerType = EndNodeController,
    classical_delay = 1e-3
)
    # Create registers for each node
    registers = Register[]
    for _ in vertices(graph)
        traits = [Qubit() for _ in 1:regsize]
        repr  = [representation() for _ in 1:regsize]
        bg    = [T2Dephasing(T2) for _ in 1:regsize]
        push!(registers, Register(traits, repr, bg))
    end

    # Build the network and get the simulation scheduler
    net = RegisterNet(graph, registers; classical_delay)
    sim = get_time_tracker(net)

    # Default: all nodes can be end nodes
    if isnothing(end_nodes)
        end_nodes = collect(vertices(graph))
    end

    # --- Launch the QTCP protocol suite ---

    # 1. EndNodeControllers on the designated end nodes
    for node in end_nodes
        ctrl = EndNodeControllerType(net, node)
        @process ctrl()
    end

    # 2. NetworkNodeControllers on ALL nodes
    for node in vertices(graph)
        ctrl = NetworkNodeController(net, node)
        @process ctrl()
    end

    # 3. LinkControllers on every edge
    for edge in edges(net)
        ctrl = LinkController(net, edge.src, edge.dst)
        @process ctrl()
    end

    return sim, net
end
