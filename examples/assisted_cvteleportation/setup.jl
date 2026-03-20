using QuantumSavory
using QuantumSavory.ProtocolZoo: AbstractProtocol
using ConcurrentSim
using ResumableFunctions
using Gabs
using Revise

"""
    RESOURCE_SQUEEZE

Shared squeezing strength used for the three-mode entangled resource.

Larger values make the teleportation closer to the ideal protocol, while smaller
values leave more finite-squeezing noise in Bob's output mode.
"""
const RESOURCE_SQUEEZE = 1.5

# Use Gabs.jl as a numerical backend for `Qumode`s and build the three-node network.
"""
    simulation_setup(; repr = GabsRepr(QuadBlockBasis))

Create the small register network used in the assisted continuous-variable
teleportation tutorial.

Alice owns two modes: her share of the entangled resource and the unknown input
mode to be teleported. Bob and Charlie each own one resource mode.
"""
function simulation_setup(; repr = GabsRepr(QuadBlockBasis))
    # initialize registers
    regA = Register([Qumode(), Qumode()], [repr, repr]) # mode a and input mode
    regB = Register([Qumode()], [repr]) # mode b
    regC = Register([Qumode()], [repr]) # mode c
    # create a network (a chain) of registers
    network = RegisterNet([regA, regB, regC])
    sim = get_time_tracker(network)
    return sim, network
end

"""
    prepare_states!(net, input_state; squeezes)

Load the unknown input state into Alice's register and prepare the three-mode
Gaussian resource shared by Alice, Bob, and Charlie.

The resource is generated from three single-mode squeezed states followed by the
beam-splitter network used in the assisted teleportation setup.
"""
function prepare_states!(net, input_state; squeezes)
    regA, regB, regC = net[1], net[2], net[3]
    # Alice's second slot holds the unknown input that will be teleported.
    initialize!(regA, 2, input_state)

    # Prepare the shared three-mode entangled resource across Alice, Bob, and Charlie.
    initialize!(regA, 1, SqueezedState(-squeezes[1]))
    initialize!(regB, 1, SqueezedState(squeezes[2]))
    initialize!(regC, 1, SqueezedState(squeezes[3]))
    apply!([regA[1], regB[1]], BeamSplitterOp(2/3))
    apply!(regB[1], PhaseShiftOp(1.0 * pi))
    apply!([regB[1], regC[1]], BeamSplitterOp(1/2))
    apply!(regC[1], PhaseShiftOp(1.0 * pi))

    # Alice mixes her resource mode with the unknown input to create the Bell-like measurement.
    apply!(regA[1:2], BeamSplitterOp(1/2))
end

"""
    AssistedTeleport(sim, net, nodeA, nodeB, nodeC)

Protocol object representing the assisted continuous-variable teleportation run.

Alice (`nodeA`) performs the Bell-like homodyne measurement, Charlie (`nodeC`)
provides the assisting quadrature, and Bob (`nodeB`) applies the final
displacement correction.
"""
struct AssistedTeleport <: AbstractProtocol
    sim::Simulation
    net::RegisterNet
    nodeA::Int # Alice (sender)
    nodeB::Int # Bob (receiver)
    nodeC::Int # Charlie (assister)
end

"""
    homodyne_alice!(net, nodeA, nodeB)

Perform Alice's Bell-like homodyne measurement and send the classical outcomes
to Bob.

With the beam-splitter convention used here, the measured `x_-` contribution is
stored with an explicit minus sign before transmission.
"""
function homodyne_alice!(net, nodeA, nodeB)
    regA = net[nodeA]
    # project Alice's register onto the eigenstates |x₋, p₊⟩
    quads₋ = project_traceout!(regA[2], HomodyneMeasurement([0.0]))
    quads₊ = project_traceout!(regA[1], HomodyneMeasurement([pi/2]))
    # put quadrature measurements in channel
    chAB = channel(net, nodeA=>nodeB)
    put!(chAB, Tag(:quadsA, -quads₋[1], quads₊[2]))
end

"""
    homodyne_charlie!(net, nodeB, nodeC)

Measure Charlie's mode in the `p` quadrature and send the result to Bob.
"""
function homodyne_charlie!(net, nodeB, nodeC)
    regC = net[nodeC]
    # project Charlie's register onto the eigenstate |p⟩
    quads = project_traceout!(regC[1], HomodyneMeasurement([pi/2]))
    # put quadrature measurement in channel
    chBC = channel(net, nodeC=>nodeB)
    put!(chBC, Tag(:quadsC, quads[2]))
end

"""
    (prot::AssistedTeleport)()

Run one assisted teleportation round.

After Alice and Charlie send their measurement outcomes, Bob applies the
displacement that reconstructs the input state on his output mode.
"""
@resumable function (prot::AssistedTeleport)()
    (; sim, net, nodeA, nodeB, nodeC) = prot
    homodyne_alice!(net, nodeA, nodeB)
    homodyne_charlie!(net, nodeB, nodeC)

    # Bob waits for the classical messages and converts them into his correction.
    regB = net[nodeB]
    mb = messagebuffer(regB)
    quadsAtag = @yield query_wait(mb, :quadsA, ❓, ❓)
    quadsA = [quadsAtag.tag[2], quadsAtag.tag[3]]
    quadsCtag = @yield query_wait(mb, :quadsC, ❓)
    D = DisplaceOp((-sqrt(2) * quadsA[1] + im * (sqrt(2) * quadsA[2] + quadsCtag.tag[2])) / 2)
    apply!(regB[1], D)
end

# Run a single teleportation instance for a random coherent input state.
sim, net = simulation_setup()
initial_state = CoherentState(rand(ComplexF64))
prepare_states!(
    net,
    initial_state;
    squeezes = fill(RESOURCE_SQUEEZE, 3)
)
teleport = AssistedTeleport(sim, net, 1, 2, 3)
@process teleport()

run(sim)

# Compare the input state with Bob's final output state.
# For sufficiently large `RESOURCE_SQUEEZE`, these should be very similar.
@show express(initial_state, GabsRepr(QuadBlockBasis))
@show QuantumSavory.stateof(net[2,1]).state[]
