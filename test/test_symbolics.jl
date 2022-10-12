using Test
using QuantumSavory

@test +(Z1) == Z1
@test +(Z) == Z
@test isequal(Z1 - Z2, Z1 + (-Z2))
@test_broken isequal(Z1 - 2*Z2 + 2*X1, -2*Z2 + Z1 + 2*X1)
@test_broken isequal(Z1 - 2*Z2 + 2*X1, Z1 + 2*(-Z2+X1))
