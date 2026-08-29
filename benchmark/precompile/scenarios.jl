using Random
const ConcurrentSim = QuantumSavory.ConcurrentSim
const QuadBlockBasis = QuantumSavory.Gabs.QuadBlockBasis
using QuantumSavory.CircuitZoo: EntanglementSwap
using QuantumSavory.ProtocolZoo: EntanglerProt
using QuantumSavory.StatesZoo: DepolarizedBellPair

bell_state() = (Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2)

function bell_core()
    register = Register(2)
    bell = bell_state()
    initialize!(register[1:2], bell)
    fidelity = real(observable(register[1:2], SProjector(bell)))
    check(isapprox(fidelity, 1; atol=1e-12), "Bell initialization failed")
    return fidelity
end

function bell()
    Random.seed!(0x5153)
    register = Register(2)
    initialize!(register[1:2], bell_state())

    first_outcome = project_traceout!(register[1], Z)
    partner_state = (Z1, Z2)[1 + Int(first_outcome == -1)]
    partner_fidelity = real(observable(register[2], SProjector(partner_state)))
    second_outcome = project_traceout!(register[2], Z)

    check(first_outcome == second_outcome, "Bell measurements did not match")
    check(isapprox(partner_fidelity, 1; atol=1e-12), "Bell partner did not collapse to the measured state")
    check(!isassigned(register, 1) && !isassigned(register, 2), "Bell measurement did not empty both slots")
    return first_outcome
end

measurement() = bell()

function clifford()
    Random.seed!(0x5154)
    register = Register(2, CliffordRepr())
    initialize!(register[1:2], StabilizerState("XX ZZ"))
    apply!(register[1], H)
    apply!(register[1], H)
    check(isapprox(real(observable(register[1:2], Z ⊗ Z)), 1; atol=1e-12), "Clifford Bell observable failed")

    first_outcome = project_traceout!(register[1], Z)
    partner_fidelity = real(observable(
        register[2], SProjector((Z1, Z2)[1 + Int(first_outcome == -1)])
    ))
    second_outcome = project_traceout!(register[2], Z)
    check(first_outcome == second_outcome, "Clifford Bell measurements did not match")
    check(isapprox(partner_fidelity, 1; atol=1e-12), "Clifford Bell partner check failed")
    return first_outcome
end

function metadata()
    register = Register(5)
    tag!(register[2], :precompile_probe, 2)
    tag!(register[3], :precompile_probe, 3)
    tag!(register[4], :other_probe, 4)

    exact = query(register, :precompile_probe, 2)
    wildcard = query(register, :precompile_probe, ❓)
    matches = queryall(register, :precompile_probe, ❓; filo=false)
    deleted = querydelete!(register[3], :precompile_probe, 3)
    free = findfreeslot(register; chooseslot=1)

    check(!isnothing(exact) && exact.slot == register[2], "Exact metadata query failed")
    check(!isnothing(wildcard) && wildcard.slot == register[3], "Wildcard metadata query failed")
    check(length(matches) == 2, "queryall metadata result was incomplete")
    check(!isnothing(deleted) && isnothing(query(register[3], :precompile_probe, 3)), "Metadata deletion failed")
    check(!isnothing(free) && free.idx == 1, "Free-slot search failed")
    return length(matches)
end

function classical_transport()
    network = RegisterNet([Register(1), Register(1)]; classical_delay=0.25)
    simulation = get_time_tracker(network)
    put!(channel(network, 1 => 2), Tag(:precompile_message, 17))
    ConcurrentSim.run(simulation, 1.0)

    received = querydelete!(messagebuffer(network, 2), :precompile_message, 17)
    check(!isnothing(received) && received.src == 1, "Classical channel delivery failed")
    check(isnothing(query(messagebuffer(network, 2), :precompile_message, 17)), "Classical message was not consumed")
    return received.src
end

function quantum_transport()
    network = RegisterNet([Register(1), Register(1)]; quantum_delay=0.25)
    simulation = get_time_tracker(network)
    initialize!(network[1][1], X1)
    quantum_channel = qchannel(network, 1 => 2)
    put!(quantum_channel, network[1][1])
    take!(quantum_channel, network[2][1])
    ConcurrentSim.run(simulation, 1.0)

    check(!isassigned(network[1], 1) && isassigned(network[2], 1), "Quantum channel did not transfer ownership")
    expectation = real(observable(network[2][1], X))
    check(isapprox(expectation, 1; atol=1e-12), "Quantum channel changed the transferred state")
    return expectation
end

function circuitzoo()
    Random.seed!(0x5155)
    network = RegisterNet([Register(1), Register(2), Register(1)])
    initialize!((network[1][1], network[2][1]), bell_state())
    initialize!((network[2][2], network[3][1]), bell_state())
    EntanglementSwap()(network[2][1], network[1][1], network[2][2], network[3][1])

    zz = real(observable((network[1][1], network[3][1]), Z ⊗ Z))
    xx = real(observable((network[1][1], network[3][1]), X ⊗ X))
    check(!isassigned(network[2], 1) && !isassigned(network[2], 2), "Entanglement swap did not consume local slots")
    check(isapprox(zz, 1; atol=1e-12) && isapprox(xx, 1; atol=1e-12), "Entanglement swap did not create a remote Bell pair")
    return zz + xx
end

function stateszoo()
    register = Register(2)
    initialize!(register[1:2], DepolarizedBellPair(1.0))
    fidelity = real(observable(register[1:2], SProjector(bell_state())))
    check(isapprox(fidelity, 1; atol=1e-12), "DepolarizedBellPair initialization failed")
    return fidelity
end

function entangler()
    Random.seed!(0x5156)
    network = RegisterNet([Register(1), Register(1)])
    simulation = get_time_tracker(network)
    protocol = EntanglerProt(
        simulation,
        network,
        1,
        2;
        chooseslotA=1,
        chooseslotB=1,
        success_prob=1.0,
        rounds=1,
    )
    ConcurrentSim.Process(protocol)
    ConcurrentSim.run(simulation, 1.0)

    fidelity = real(observable((network[1][1], network[2][1]), SProjector(bell_state())))
    check(isapprox(fidelity, 1; atol=1e-12), "EntanglerProt did not create the requested Bell pair")
    return fidelity
end

function quantummc()
    Random.seed!(0x5157)
    register = Register(2, QuantumMCRepr())
    initialize!(register[1:2], StabilizerState("XX ZZ"))
    first_outcome = project_traceout!(register[1], Z)
    check(!isassigned(register, 1) && isassigned(register, 2), "QuantumMC measurement did not trace out one qubit")
    partner_fidelity = real(observable(
        register[2], SProjector((Z1, Z2)[1 + Int(first_outcome == -1)])
    ))
    check(isapprox(partner_fidelity, 1; atol=1e-12), "QuantumMC measurement or traceout failed")
    return partner_fidelity
end

function gabs()
    Random.seed!(0x5158)
    representation = GabsRepr(QuadBlockBasis)
    register = Register(fill(Qumode(), 2), fill(representation, 2))
    initialize!(register[1:2], TwoSqueezedState(0.45))
    result = project_traceout!(register[1], HomodyneMeasurement([0.0]))
    check(result isa Real && isfinite(result), "Gabs homodyne returned an invalid quadrature")
    check(!isassigned(register, 1) && isassigned(register, 2), "Gabs homodyne did not trace out one mode")
    return result
end

const PRECOMPILE_BENCHMARKS = (
    bell=bell,
    bell_core=bell_core,
    measurement=measurement,
    clifford=clifford,
    metadata=metadata,
    classical_transport=classical_transport,
    quantum_transport=quantum_transport,
    circuitzoo=circuitzoo,
    stateszoo=stateszoo,
    entangler=entangler,
    quantummc=quantummc,
    gabs=gabs,
)
