SUITE["import"] = BenchmarkGroup(["import"])

# Time to import the package (measured separately since it only happens once)
SUITE["import"]["time"] = @benchmarkable begin
    @eval using QuantumSavory, QuantumSavory.ProtocolZoo, ResumableFunctions, ConcurrentSim
end samples=1 evals=1

# Time to precompile
SUITE["import"]["precompile"] = @benchmarkable begin
    @eval include("../src/precompile.jl")
end samples=1 evals=1
