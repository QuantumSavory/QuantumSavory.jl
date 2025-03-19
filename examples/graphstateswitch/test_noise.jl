using QuantumSavory
using QuantumSavory.CircuitZoo
using QuantumSavory.ProtocolZoo
using QuantumSymbolics
using QuantumOpticsBase: Operator
using QuantumClifford: AbstractStabilizer, Stabilizer, sHadamard, sPhase, sSWAP, canonicalize!, graphstate, PauliOperator, dm
using Graphs


traits = [Qubit(), Qubit(), Qubit()]
bg = [T2Dephasing(1.0), T2Dephasing(1.0), T2Dephasing(1.0)]
repr = [CliffordRepr(), CliffordRepr(), CliffordRepr()]
r = Register(traits, repr)
net = RegisterNet([r]) # network layout
sim = get_time_tracker(net)

graph = Graph(3)
add_edge!(graph, 1, 2)
add_edge!(graph, 2, 3)

ψ = StabilizerState(Stabilizer(graph))
ψ = SProjector(ψ)
initialize!(r[1:3],ψ,time=0.0)

## This only works in QuantumOpticsRepr()
# test 1
# @info real(observable(r[1:3], σᶻ⊗σˣ⊗σᶻ; time=1.0)) # Z for the first and last qubit, X for the middle qubit
# @info real(observable([r[2], r[1], r[3]], σˣ⊗σᶻ⊗σᶻ; time=2.0)) # This does not work -- rearranging the registers does not rearrange the state vector stored in the register

# test 2
# fid = map(vertices(graph)) do v
#     neighs = neighbors(graph, v)
#     verts = sort([v, neighs...])
#     obs = express(reduce(⊗,[ (i == v) ? σˣ : σᶻ for i in verts ]), CliffordRepr(), UseAsObservable()) # X for the central vertex v, Z for neighbors, Kronecker them together       
#     regs = [net[1, i] for i in sort([v, neighs...])] 
#     observable(regs, obs; time=3.0) # calculate the value of the observable
# end
# @info fid

# test 3
helperreg = Register(traits, repr)
initialize!(helperreg[1:3], Ket(r.staterefs[1].state[]))

fid = map(vertices(graph)) do v
    neighs = neighbors(graph, v)
    verts = sort([v, neighs...])
    obs = reduce(⊗,[ (i == v) ? σˣ : σᶻ for i in verts ]) # X for the central vertex v, Z for neighbors, Kronecker them together       
    regs = helperreg[sort([v, neighs...])] 
    observable(regs, obs; time=3.0) # calculate the value of the observable
end
@info fid


