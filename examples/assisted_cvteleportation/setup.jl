using Graphs
using ConcurrentSim
using ResumableFunctions
using QuantumSavory
using QuantumSavory.ProtocolZoo: AbstractProtocol
using Gabs
using Revise

# use Gabs.jl as a numerical backend for `Qumode`s
function simulation_setup(; repr = GabsRepr(QuadBlockBasis))
    # initialize registers
    regA = Register([Qumode(), Qumode()], [repr, repr]) # mode a and input mode
    regB = Register([Qumode()], [repr]) # mode b
    regC = Register([Qumode()], [repr]) # mode c
    # create a network of registers
    graph = Graphs.grid([3])
    network = RegisterNet(graph, [regA, regB, regC])
    sim = get_time_tracker(network)
    return sim, network
end
function prepare_states!(net, input_state; squeezes)
    regA, regB, regC = net[1], net[2], net[3]
    # insert "unknown" initial state into Alice's register
    initialize!(regA, 2, input_state)
    # prepare 3-mode epr state between a, b, c
    for i in eachindex(squeezes)
        initialize!(net[i], 1, SqueezedState(squeezes[i]))
    end 
    apply!([regA, regB], [1, 1], BeamSplitterOp(1/2))
    apply!([regB, regC], [1, 1], BeamSplitterOp(1/3))
    # mix a and input
    apply!(regA[1:2], BeamSplitterOp(1/2))
end

struct AssistedTeleport <: AbstractProtocol
    sim::Simulation
    net::RegisterNet
    nodeA::Int # Alice (sender)
    nodeB::Int # Bob (receiver)
    nodeC::Int # Charlie (assister)
end
function homodyne_alice!(net, nodeA, nodeB)
    regA = net[nodeA]
    # project Alice's register onto the eigenstates |x₋, p₊⟩
    quads₋, _ = project_traceout!(regA, 1, HomodyneMeasurement([0.0]))
    quads₊, _ = project_traceout!(regA, 2, HomodyneMeasurement([pi/2]))
    # put quadrature measurements in channel
    chAB = channel(net, nodeA=>nodeB)
    put!(chAB, [quads₋, quads₊])
end
function homodyne_charlie!(net, nodeB, nodeC)
    regC = net[nodeC]
    # project Charlie's register onto the eigenstate |x₋⟩
    quads = project_traceout!(regC, 1, HomodyneMeasurement([0.0]))
    # put quadrature measurement in channel
    chBC = channel(net, nodeC=>nodeB)
    put!(chBC, quads)
end
@resumable function (prot::AssistedTeleport)()
    (; sim, net, nodeA, nodeB, nodeC) = prot
    homodyne_alice!(net, nodeA, nodeB)
    homodyne_charlie!(net, nodeB, nodeC)
    # assist bob
    chAB = channel(net, nodeA=>nodeB)
    chBC = channel(net, nodeC=>nodeB)
    regB = net[nodeB]
    quadsA = @yield take!(chAB)
    quadsC = @yield take!(chBC)
    D = DisplaceOp(quadsA[1] + quadsC[1] + im * quadsA[2])
    apply!(regB, [1], D)
end

sim, net = simulation_setup()
prepare_states!(
    net,
    CoherentState(rand(ComplexF64)); 
    squeezes = [rand(ComplexF64) for _ in 1:3]
)
teleport = AssistedTeleport(sim, net, 1, 2, 3)
@process teleport()

run(sim)