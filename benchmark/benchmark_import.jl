using BenchmarkTools

SUITE["import"] = BenchmarkGroup(["import"])

# time to run `using QuantumSavory`
SUITE["import"]["using_QuantumSavory"] = @benchmarkable run(`julia --project=$(joinpath(@__DIR__, "..")) -e "using QuantumSavory"`) samples=1 evals=1
