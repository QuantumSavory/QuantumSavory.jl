using BenchmarkTools
using Pkg
using StableRNGs
using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumSavory: tag_types
using QuantumOpticsBase: Ket, Operator
using QuantumClifford: MixedDestabilizer, ghz

const SUITE = BenchmarkGroup()

rng = StableRNG(42)

M = Pkg.Operations.Context().env.manifest
V = M[findfirst(v -> v.name == "QuantumSavory", M)].version

include("benchmark_register.jl")
include("benchmark_tagquery.jl")
include("benchmark_quantumstates.jl")
