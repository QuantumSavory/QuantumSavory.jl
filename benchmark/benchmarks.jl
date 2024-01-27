using BenchmarkTools
using Pkg
using StableRNGs
using QuantumSavory
using QuantumSavory: tag_types
using QuantumOpticsBase: Ket, Operator
using QuantumClifford: MixedDestabilizer

const SUITE = BenchmarkGroup()

rng = StableRNG(42)

M = Pkg.Operations.Context().env.manifest
V = M[findfirst(v -> v.name == "QuantumSavory", M)].version

SUITE["register"] = BenchmarkGroup(["register"])
SUITE["register"]["creation_and_initialization"] = BenchmarkGroup(["creation_and_initialization"])
function register_creation_and_initialization()
    traits = [Qubit(), Qubit(), Qubit()]
    reg1 = Register(traits)
    qc_repr = [QuantumOpticsRepr(), CliffordRepr(), CliffordRepr()]
    reg2 = Register(traits, qc_repr)
    qmc_repr = [QuantumOpticsRepr(), QuantumMCRepr(), QuantumMCRepr()]
    reg3 = Register(traits, qmc_repr)
    net = RegisterNet([reg1, reg2, reg3])

    i = 1
    initialize!(net[i,2])
    @assert nsubsystems(net[i].staterefs[2]) == 1
    initialize!(net[i,3],X1)
    @assert nsubsystems(net[i].staterefs[2]) == 1
    apply!([net[i,2], net[i,3]], CNOT)
    @assert net[i].staterefs[2].state[] isa Ket
    @assert nsubsystems(net[i].staterefs[2]) == 2

    i = 2
    initialize!(net[i,2])
    @assert nsubsystems(net[i].staterefs[2]) == 1
    initialize!(net[i,3],X1)
    @assert nsubsystems(net[i].staterefs[2]) == 1
    apply!([net[i,2], net[i,3]], CNOT)
    @assert net[i].staterefs[2].state[] isa MixedDestabilizer
    @assert nsubsystems(net[i].staterefs[2]) == 2

    i = 3
    initialize!(net[i,2])
    @assert nsubsystems(net[i].staterefs[2]) == 1
    initialize!(net[i,3],X1)
    @assert nsubsystems(net[i].staterefs[2]) == 1
    apply!([net[i,2], net[i,3]], CNOT)
    @assert net[i].staterefs[2].state[] isa Ket
    @assert nsubsystems(net[i].staterefs[2]) == 2

    ##
    # with backgrounds
    traits = [Qubit(), Qubit(), Qubit()]
    backgrounds = [T2Dephasing(1.0),T2Dephasing(1.0),T2Dephasing(1.0)]
    reg1 = Register(traits, backgrounds)
    qc_repr = [QuantumOpticsRepr(), CliffordRepr(), CliffordRepr()]
    reg2 = Register(traits, qc_repr, backgrounds)
    qmc_repr = [QuantumOpticsRepr(), QuantumMCRepr(), QuantumMCRepr()]
    reg3 = Register(traits, qmc_repr, backgrounds)
    net = RegisterNet([reg1, reg2, reg3])

    i = 1
    initialize!(net[i,2], time=1.0)
    @assert nsubsystems(net[i].staterefs[2]) == 1
    initialize!(net[i,3],X1, time=2.0)
    @assert nsubsystems(net[i].staterefs[2]) == 1
    apply!([net[i,2], net[i,3]], CNOT, time=3.0)
    @assert net[i].staterefs[2].state[] isa Operator
    @assert nsubsystems(net[i].staterefs[2]) == 2

    i = 2
    initialize!(net[i,2], time=1.0)
    @assert nsubsystems(net[i].staterefs[2]) == 1
    initialize!(net[i,3],X1, time=2.0)
    @assert nsubsystems(net[i].staterefs[2]) == 1
    apply!([net[i,2], net[i,3]], CNOT, time=3.0)
    @assert net[i].staterefs[2].state[] isa MixedDestabilizer
    @assert nsubsystems(net[i].staterefs[2]) == 2

    i = 3
    initialize!(net[i,2], time=1.0)
    @assert nsubsystems(net[i].staterefs[2]) == 1
    initialize!(net[i,3],X1, time=2.0)
    @assert nsubsystems(net[i].staterefs[2]) == 1
    apply!([net[i,2], net[i,3]], CNOT, time=3.0)
    @assert nsubsystems(net[i].staterefs[2]) == 2
end
SUITE["register"]["creation_and_initialization"]["from_tests"] = @benchmarkable register_creation_and_initialization()

SUITE["tagquery"] = BenchmarkGroup(["tagquery"])
SUITE["tagquery"]["misc"] = BenchmarkGroup(["misc"])
function tagquery_interfacetest()
    r = Register(10)
    tag!(r[1], :symbol1, 2, 3)
    tag!(r[2], :symbol1, 4, 5)
    tag!(r[5], Int, 4, 5)

    @assert Tag(:symbol1, 2, 3) == tag_types.SymbolIntInt(:symbol1, 2, 3)
    @assert query(r, :symbol1, 4, ❓) == (slot=r[2], tag=tag_types.SymbolIntInt(:symbol1, 4, 5))
    @assert query(r, :symbol1, 4, 5) == (slot=r[2], tag=tag_types.SymbolIntInt(:symbol1, 4, 5))
    @assert query(r, :symbol1, ❓, ❓) == (slot=r[1], tag=tag_types.SymbolIntInt(:symbol1, 2, 3))
    @assert query(r, :symbol2, ❓, ❓) == nothing
    @assert query(r, Int, 4, 5) == (slot=r[5], tag=tag_types.TypeIntInt(Int, 4, 5))
    @assert query(r, Float32, 4, 5) == nothing
    @assert query(r, Int, 4, >(5)) == nothing
    @assert query(r, Int, 4, <(6)) == (slot=r[5], tag=tag_types.TypeIntInt(Int, 4, 5))

    @assert queryall(r, :symbol1, ❓, ❓) == [(slot=r[1], tag=tag_types.SymbolIntInt(:symbol1, 2, 3)), (slot=r[2], tag=tag_types.SymbolIntInt(:symbol1, 4, 5))]
    @assert isempty(queryall(r, :symbol2, ❓, ❓))

    @assert query(r[2], Tag(:symbol1, 4, 5)) == (depth=1, tag=Tag(:symbol1, 4, 5))
    @assert queryall(r[2], Tag(:symbol1, 4, 5)) == [(depth=1, tag=Tag(:symbol1, 4, 5))]
    @assert query(r[2], :symbol1, 4, 5) == (depth=1, tag=Tag(:symbol1, 4, 5))
    @assert queryall(r[2], :symbol1, 4, 5) == [(depth=1, tag=Tag(:symbol1, 4, 5))]

    @assert query(r[2], :symbol1, 4, ❓) == (depth=1, tag=Tag(:symbol1, 4, 5))
    @assert queryall(r[2], :symbol1, 4, ❓) == [(depth=1, tag=Tag(:symbol1, 4, 5))]

    @assert querydelete!(r[2], :symbol1, 4, ❓) == Tag(:symbol1, 4, 5)
    @assert querydelete!(r[2], :symbol1, 4, ❓) === nothing
end
SUITE["tagquery"]["misc"]["from_tests"] = @benchmarkable tagquery_interfacetest()
