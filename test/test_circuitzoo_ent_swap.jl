using QuantumSavory
using QuantumSavory.CircuitZoo
using Test
using QuantumSavory.CircuitZoo: EntanglementSwap, LocalEntanglementSwap

const perfect_pair_stab = StabilizerState("XX ZZ")
const perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)

for pair in (perfect_pair, perfect_pair_stab), rep in 1:10
    net = RegisterNet([Register(1), Register(2), Register(1)])
    initialize!((net[1][1], net[2][1]), pair)
    initialize!((net[3][1], net[2][2]), pair)
    EntanglementSwap()(net[2][1], net[1][1], net[2][2], net[3][1])
    @test !isassigned(net[2][1]) && !isassigned(net[2][2])
    @test observable((net[1][1], net[3][1]), Z⊗Z) ≈ 1
    @test observable((net[1][1], net[3][1]), X⊗X) ≈ 1
end

for pair in (perfect_pair, perfect_pair_stab), rep in 1:10
    net = RegisterNet([Register(1), Register(2), Register(1)])
    initialize!((net[1][1], net[2][1]), pair)
    initialize!((net[3][1], net[2][2]), pair)
    mx, mz = LocalEntanglementSwap()(net[2][1], net[2][2])
    mx == 2 && apply!(net[1][1], Z)
    mz == 2 && apply!(net[3][1], X)
    @test !isassigned(net[2][1]) && !isassigned(net[2][2])
    @test observable((net[1][1], net[3][1]), Z⊗Z) ≈ 1
    @test observable((net[1][1], net[3][1]), X⊗X) ≈ 1
end

for pair in (perfect_pair, perfect_pair_stab), n in 3:10, rep in 1:10
    net = RegisterNet([Register(2) for i in 1:n])
    for i in 1:n-1
        initialize!((net[i][1], net[i+1][2]), pair)
    end
    for i in 2:n-1
        EntanglementSwap()(net[i][2], net[1][1], net[i][1], net[i+1][2])
    end
    @test all(!isassigned(net[i][1]) & !isassigned(net[i][2]) for i in 2:n-1)
    @test observable((net[1][1], net[n][2]), Z⊗Z) ≈ 1
    @test observable((net[1][1], net[n][2]), X⊗X) ≈ 1
end

for pair in (perfect_pair, perfect_pair_stab), n in 3:10, rep in 1:10
    net = RegisterNet([Register(2) for i in 1:n])
    for i in 1:n-1
        initialize!((net[i][1], net[i+1][2]), pair)
    end
    for i in 2:n-1
        mx, mz = LocalEntanglementSwap()(net[i][2], net[i][1])
        mx == 2 && apply!(net[1][1], Z)
        mz == 2 && apply!(net[i+1][2], X)
    end
    @test all(!isassigned(net[i][1]) & !isassigned(net[i][2]) for i in 2:n-1)
    @test observable((net[1][1], net[n][2]), Z⊗Z) ≈ 1
    @test observable((net[1][1], net[n][2]), X⊗X) ≈ 1
end
