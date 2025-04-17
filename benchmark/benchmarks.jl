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

    @assert Tag(:symbol1, 2, 3) == Tag(:symbol1, 2, 3)
    @assert query(r, :symbol1, 4, ❓).tag == Tag(:symbol1, 4, 5)
    @assert query(r, :symbol1, 4, 5).tag == Tag(:symbol1, 4, 5)
    @assert query(r, :symbol1, ❓, ❓).tag == Tag(:symbol1, 4, 5)
    @assert query(r, :symbol2, ❓, ❓) == nothing
    @assert query(r, Int, 4, 5).tag == Tag(Int, 4, 5)
    @assert query(r, Float32, 4, 5) == nothing
    @assert query(r, Int, 4, >(5)) == nothing
    @assert query(r, Int, 4, <(6)).tag == Tag(Int, 4, 5)

    @assert [r.tag for r in queryall(r, :symbol1, ❓, ❓)] == [Tag(:symbol1, 4, 5),Tag(:symbol1, 2, 3)]
    @assert isempty(queryall(r, :symbol2, ❓, ❓))

    @assert query(r[2], Tag(:symbol1, 4, 5)).tag == Tag(:symbol1, 4, 5)
    @assert [r.tag for r in queryall(r[2], Tag(:symbol1, 4, 5))] == [Tag(:symbol1, 4, 5)]
    @assert query(r[2], :symbol1, 4, 5).tag == Tag(:symbol1, 4, 5)
    @assert [r.tag for r in queryall(r[2], :symbol1, 4, 5)] == [Tag(:symbol1, 4, 5)]

    @assert query(r[2], :symbol1, 4, ❓).tag == Tag(:symbol1, 4, 5)
    @assert [r.tag for r in queryall(r[2], :symbol1, 4, ❓)] == [Tag(:symbol1, 4, 5)]

    @assert querydelete!(r[2], :symbol1, 4, ❓).tag == Tag(:symbol1, 4, 5)
    @assert querydelete!(r[2], :symbol1, 4, ❓) === nothing
end
SUITE["tagquery"]["misc"]["from_tests"] = @benchmarkable tagquery_interfacetest()

SUITE["tagquery"]["register"] = BenchmarkGroup(["register"])
reg = Register(5)
tag!(reg[3], EntanglementCounterpart, 1, 10)
tag!(reg[3], EntanglementCounterpart, 2, 21)
tag!(reg[3], EntanglementCounterpart, 3, 30)
tag!(reg[3], EntanglementCounterpart, 2, 22)
tag!(reg[3], EntanglementCounterpart, 1, 10)
tag!(reg[3], EntanglementCounterpart, 6, 60)
tag!(reg[3], EntanglementCounterpart, 2, 23)
tag!(reg[3], EntanglementCounterpart, 1, 10)
SUITE["tagquery"]["register"]["query"] = @benchmarkable @benchmark query(reg, EntanglementCounterpart, 6, ❓; filo=true)
SUITE["tagquery"]["register"]["queryall"] = @benchmarkable @benchmark queryall(reg, EntanglementCounterpart, 6, ❓; filo=true)

SUITE["tagquery"]["messagebuffer"] = BenchmarkGroup(["messagebuffer"])
net = RegisterNet([Register(3), Register(2), Register(3)])
mb = messagebuffer(net, 2)
put!(mb, Tag(EntanglementCounterpart, 1, 10))
put!(mb, Tag(EntanglementCounterpart, 2, 21))
put!(mb, Tag(EntanglementCounterpart, 3, 30))
put!(mb, Tag(EntanglementCounterpart, 2, 22))
put!(mb, Tag(EntanglementCounterpart, 1, 10))
put!(mb, Tag(EntanglementCounterpart, 6, 60))
put!(mb, Tag(EntanglementCounterpart, 2, 23))
put!(mb, Tag(EntanglementCounterpart, 1, 10))
SUITE["tagquery"]["messagebuffer"]["query"] = @benchmarkable query(mb, EntanglementCounterpart, 6, ❓)
SUITE["tagquery"]["messagebuffer"]["querydelete"] = @benchmarkable querydelete!(_mb, EntanglementCounterpart, 6, ❓) setup=(_mb = deepcopy(mb))  evals=1


SUITE["quantumstates"] = BenchmarkGroup(["quantumstates"])
SUITE["quantumstates"]["observable"] = BenchmarkGroup(["observable"])
state = StabilizerState(ghz(5))
proj = projector(state)
express(state)
express(proj)
SUITE["quantumstates"]["observable"]["quantumoptics"] = @benchmarkable observable(reg[1:5], proj) setup=(reg=Register(10); initialize!(reg[1:5], state)) evals=1
