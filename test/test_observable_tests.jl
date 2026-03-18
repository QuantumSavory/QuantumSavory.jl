@testitem "Observable" begin
using Test
using QuantumSavory
using QuantumClifford: Stabilizer
using Graphs: Graph, add_edge!, add_vertices!
using QuantumOpticsBase: Ket

@testset "entangled observable" begin
    bell = StabilizerState("XX ZZ")
    # or equivalently `const bell = (Z₁⊗Z₁+Z₂⊗Z₂)/√2`,
    # however converting to stabilizer state for Clifford simulations
    # is not implemented (and can not be done efficiently).

    for rep in [QuantumOpticsRepr(), CliffordRepr()]
        a = Register(2,rep)
        initialize!(a[1:2], bell)
        @test observable(a[1:2], SProjector(bell)) ≈ 1.0
        @test observable(a[1:2], σˣ⊗σˣ) ≈ 1.0
        apply!(a[1], σʸ)
        @test observable(a[1:2], SProjector(bell)) ≈ 0.0 atol=1e-5
        @test observable(a[1:2], σˣ⊗σˣ) ≈ -1.0
    end
end

@testset "separable observable with order flipping" begin
    A = StabilizerState("X")
    B = StabilizerState("Z")
    AB = StabilizerState("XI IZ")
    BA = StabilizerState("ZI IX")

    for rep in [QuantumOpticsRepr(), CliffordRepr()]
        r1 = Register(2,rep)
        r2 = Register(2,rep)
        r12 = Register(2,rep)
        r21 = Register(2,rep)

        initialize!(r1[1], A)
        initialize!(r2[2], B)
        initialize!(r12[1:2], AB)
        initialize!((r21[2], r21[1]), BA)

        @test observable(r12[1:2], SProjector(AB)) ≈ 1.0
        if rep == CliffordRepr()
            @test_throws "entangled with other qubits" observable(r12[1], SProjector(A)) ≈ 1.0
        else
            @test observable(r12[1], SProjector(A)) ≈ 1.0
        end
        @test observable(r21[1:2], SProjector(AB)) ≈ 1.0
        @test_broken observable((r1[1], r2[2]), SProjector(AB)) ≈ 1.0
        @test observable(r1[1], SProjector(A)) ≈ 1.0
        @test observable(r2[2], SProjector(B)) ≈ 1.0
    end
end

@testset "observables of permuted subsystems" begin
    pm = 3 # "piecemaker"
    function prep_system(bg, cz_order=[1,2]) # the order matters because in enforces in what order tensor products are done to build up the larger Hilbert space
        regA = Register([Qubit() for _ in 1:3], [bg for _ in 1:3]) # Alice
        regB = Register([Qubit() for _ in 1:3], [bg for _ in 1:3]) # Bob

        net = RegisterNet([regA, regB])

        # Alice and Bob share three bell pairs
        bell = StabilizerState("XX ZZ")
        for i in 1:3
            initialize!((net[1][i], net[2][i]), bell)
        end

        # Alice applies CZ gates to create "ZZX XIZ IXZ" and measures in X
        for i in cz_order
            apply!((net[1][pm], net[1][i]), ZCZ)
        end
        for i in 1:3
            zmeas = project_traceout!(net[1][i], X)
            if zmeas==2 apply!(net[2][i], Z) end # Bob applies correction immediately after Alice's measurement (ftl)
        end

        return net
    end

    # Reference graph state
    graph = Graph()
    add_vertices!(graph, 3)
    add_edge!(graph, (1, pm))
    add_edge!(graph, (2, pm))
    ref_stab = Stabilizer(graph) # using directly the QuantumClifford backend (bad style -- backend APIs are "non-standard" and should be hidden)
    ref_ket = Ket(ref_stab)      # using directly the QuantumOptics backend (bad style -- backend APIs are "non-standard" and should be hidden)
    ref_manual = StabilizerState("X_Z _XZ ZZX") # good -- this uses only the QuantumSavory namespace and does not depend on knowledge of backend APIs
    ref_stab2 = StabilizerState(ref_stab) # kinda ok -- in some situations it might be natural to use another library to prepare a description of some interesting state, and here we are converting that "external" state to QuantumSavory-native type

    bg_qo = QuantumOpticsRepr()
    bg_qc = CliffordRepr()
    net_qo = prep_system(bg_qo)
    net_qc = prep_system(bg_qc)
    net_qo2 = prep_system(bg_qo, [2,1])
    net_qc2 = prep_system(bg_qc, [2,1])

    # confirm that the result is the same in both backends (state indexing does not have to be the same in each backend, but it happens to be the same for this particular circuit)
    @test Ket(QuantumSavory.stateof(net_qc[2][1]).state[]) ≈ QuantumSavory.stateof(net_qo[2][1]).state[]
    @test Ket(QuantumSavory.stateof(net_qc2[2][1]).state[]) ≈ QuantumSavory.stateof(net_qo2[2][1]).state[]

    # calculating fidelity in a few different ways

    @test observable(net_qc[2][1:3], projector(ref_stab)) ≈ 1
    @test observable(net_qc[2][1:3], projector(ref_stab2)) ≈ 1
    @test_broken observable(net_qc[2][1:3], projector(ref_ket)) ≈ 1 # TODO state::MixedDestabilizer, operator::QuantumOpticsBase.Operator is not supported yet
    @test observable(net_qc[2][1:3], projector(ref_manual)) ≈ 1

    @test observable(net_qo[2][1:3], projector(ref_stab)) ≈ 1
    @test observable(net_qo[2][1:3], projector(ref_stab2)) ≈ 1
    @test observable(net_qo[2][1:3], projector(ref_ket)) ≈ 1
    @test observable(net_qo[2][1:3], projector(ref_manual)) ≈ 1

    @test observable(net_qc2[2][1:3], projector(ref_stab)) ≈ 1
    @test observable(net_qc2[2][1:3], projector(ref_stab2)) ≈ 1
    @test_broken observable(net_qc2[2][1:3], projector(ref_ket)) ≈ 1 # TODO state::MixedDestabilizer, operator::QuantumOpticsBase.Operator is not supported yet
    @test observable(net_qc2[2][1:3], projector(ref_manual)) ≈ 1

    @test observable(net_qo2[2][1:3], projector(ref_stab)) ≈ 1
    @test observable(net_qo2[2][1:3], projector(ref_stab2)) ≈ 1
    @test observable(net_qo2[2][1:3], projector(ref_ket)) ≈ 1
    @test observable(net_qo2[2][1:3], projector(ref_manual)) ≈ 1
end

end
