@testitem "RegisterNet Interface" tags=[:registernet_interface] begin
using Test
using QuantumSavory
using Graphs
using QuantumOpticsBase: Ket, Operator
using QuantumClifford: MixedDestabilizer

##

r1 = Register(3)
r2 = Register(4)
r3 = Register(5)

net = RegisterNet([r1, r2, r3])

@test net[1,2] == r1[2]
@test net[2,3] == r2[3]

net[1,:label] = "lala"
@test net[1,:label] == "lala"
end
