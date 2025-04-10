using QuantumSavory
using QuantumSavory.ProtocolZoo
using ConcurrentSim
using Graphs
using Random
using Test

##

function setup_qtcp_grid_network(grid_size::Tuple{Int,Int}=(4,4))
    rows, cols = grid_size
    num_nodes = rows * cols

    # Create grid topology
    g = grid([rows, cols])

    # Pre-allocate registers for each node
    registers = [Register(10) for _ in 1:num_nodes]  # 10 qubits per node

    # Create network with pre-allocated registers
    net = RegisterNet(g, registers)

    # Extract simulation from network
    sim = get_time_tracker(net)

    # Create protocols at each node
    for node in 1:num_nodes
        # Add EndNodeController protocol
        end_controller = EndNodeController(sim, net, node)
        @process end_controller()

        # Add NetworkNodeProtocol
        network_controller = NetworkNodeController(sim, net, node)
        @process network_controller()
    end

    # Create LinkControllers for each link
    for (;src, dst) in edges(g)
        link_controller = LinkController(sim, net, src, dst)
        @process link_controller()
    end

    # Create a single initial flow
    # Flow from node 1 to node num_nodes (diagonal of the grid)
    initial_flow = Flow(
        src=1,
        dst=num_nodes,
        npairs=3,
        uuid=1
    )
    put!(net[1], initial_flow)

    return sim, net
end

println("Setting up grid network")
sim, net = setup_qtcp_grid_network((3,3))
println("Running simulation")
run(sim, 10)

##
