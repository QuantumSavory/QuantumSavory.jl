using QuantumSavory.CircuitZoo: EntanglementSwap, LocalEntanglementSwap, Purify2to1, Purify2to1Node, SDDecode, SDEncode

SUITE["circuitzoo"] = BenchmarkGroup(["circuitzoo"])
SUITE["circuitzoo"]["entanglement_swap"] = BenchmarkGroup(["entanglement_swap"])
SUITE["circuitzoo"]["purification"] = BenchmarkGroup(["purification"])
SUITE["circuitzoo"]["superdense"] = BenchmarkGroup(["superdense"])

const CIRCUITZOO_BELL_STATE = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2.0)
const CIRCUITZOO_BELL_STABILIZER = StabilizerState("XX ZZ")

function prepare_entanglement_swap_state(pair)
    net = RegisterNet([Register(1), Register(2), Register(1)])
    initialize!((net[1][1], net[2][1]), pair)
    initialize!((net[3][1], net[2][2]), pair)
    return net
end

function run_entanglement_swap!(net)
    EntanglementSwap()(net[2][1], net[1][1], net[2][2], net[3][1])
    @assert !isassigned(net[2][1]) && !isassigned(net[2][2])
    @assert observable((net[1][1], net[3][1]), Z⊗Z) ≈ 1
    @assert observable((net[1][1], net[3][1]), X⊗X) ≈ 1
    return nothing
end

function run_local_entanglement_swap!(net)
    mx, mz = LocalEntanglementSwap()(net[2][1], net[2][2])
    mx == 2 && apply!(net[1][1], Z)
    mz == 2 && apply!(net[3][1], X)
    @assert !isassigned(net[2][1]) && !isassigned(net[2][2])
    @assert observable((net[1][1], net[3][1]), Z⊗Z) ≈ 1
    @assert observable((net[1][1], net[3][1]), X⊗X) ≈ 1
    return nothing
end

function prepare_purification_state(representation)
    reg = Register(4, representation())
    initialize!(reg[1:4], CIRCUITZOO_BELL_STABILIZER⊗CIRCUITZOO_BELL_STABILIZER)
    return reg
end

function run_purify_2to1!(reg)
    @assert Purify2to1(:Z)(reg[1:4]...)
    return nothing
end

function run_purify_2to1_node!(reg)
    @assert Purify2to1Node(:Z)(reg[1], reg[3]) == Purify2to1Node(:Z)(reg[2], reg[4])
    return nothing
end

function prepare_superdense_state()
    reg = Register(2)
    initialize!(reg[1], Z1)
    initialize!(reg[2], Z1)
    apply!(reg[1], H)
    apply!((reg[1], reg[2]), CNOT)
    return reg
end

function run_superdense_roundtrip!(reg)
    message = (1, 0)
    SDEncode()(reg[1], message)
    @assert SDDecode()(reg[1], reg[2]) == message
    return nothing
end

# CircuitZoo primitives mutate their input registers, so each benchmark uses a
# fresh setup state and a single eval to avoid measuring an already-consumed circuit.
SUITE["circuitzoo"]["entanglement_swap"]["global_quantumoptics"] = @benchmarkable run_entanglement_swap!(net) setup=(net = prepare_entanglement_swap_state(CIRCUITZOO_BELL_STATE)) evals=1

SUITE["circuitzoo"]["entanglement_swap"]["global_clifford"] = @benchmarkable run_entanglement_swap!(net) setup=(net = prepare_entanglement_swap_state(CIRCUITZOO_BELL_STABILIZER)) evals=1

SUITE["circuitzoo"]["entanglement_swap"]["local_clifford"] = @benchmarkable run_local_entanglement_swap!(net) setup=(net = prepare_entanglement_swap_state(CIRCUITZOO_BELL_STABILIZER)) evals=1

SUITE["circuitzoo"]["purification"]["purify2to1_quantumoptics"] = @benchmarkable run_purify_2to1!(reg) setup=(reg = prepare_purification_state(QuantumOpticsRepr)) evals=1

SUITE["circuitzoo"]["purification"]["purify2to1_clifford"] = @benchmarkable run_purify_2to1!(reg) setup=(reg = prepare_purification_state(CliffordRepr)) evals=1

SUITE["circuitzoo"]["purification"]["purify2to1_node_clifford"] = @benchmarkable run_purify_2to1_node!(reg) setup=(reg = prepare_purification_state(CliffordRepr)) evals=1

SUITE["circuitzoo"]["superdense"]["roundtrip"] = @benchmarkable run_superdense_roundtrip!(reg) setup=(reg = prepare_superdense_state()) evals=1
