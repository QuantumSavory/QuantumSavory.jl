@testitem "Circuit Zoo Fusion" tags=[:circuitzoo_fusion] begin
using Test
using Graphs
using QuantumSavory
using QuantumSavory.CircuitZoo
using QuantumSavory.CircuitZoo: Fusion
import QuantumClifford
import QuantumOpticsBase

const pairstate = StabilizerState("ZX XZ")
const communication_slot = 1
const storage_slot = 2

for n in 2:6, k in 1:5
    if k < n && n*k % 2 == 0
        local_topology = state_graph = random_regular_graph(n, k)
        if is_connected(state_graph)
            registers = [Register(2) for i in vertices(local_topology)]
            net = RegisterNet(local_topology, registers)
            for e in edges(state_graph)
                i, j = src(e), dst(e)
                regA = net[i]
                regB = net[j]
                initialize!((regA[communication_slot], regB[communication_slot]), pairstate)
                Fusion()(regA, regB, communication_slot, storage_slot)
            end
            for i in 1:nv(state_graph)
                o = observable([reg[storage_slot] for reg in registers], QuantumOpticsBase.Operator(QuantumClifford.Stabilizer(state_graph)[i]))
                @test o ≈ 1.0
            end
        end
    end
end
end
