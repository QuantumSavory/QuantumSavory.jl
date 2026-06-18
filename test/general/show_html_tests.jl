using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo
using Gabs

@testset "show text/html" begin

#out = stdout
out = IOBuffer()

reg = Register([Qubit(), Qumode()], [CliffordRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])

initialize!(reg[1], X1)

show(out, MIME"text/html"(), reg[1])
show(out, MIME"text/html"(), reg[2])
show(out, MIME"text/html"(), QuantumSavory.stateof(reg[1]))

reg1 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
reg2 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
net = RegisterNet([reg1, reg2])

initialize!((reg1[1],reg2[1]), X1⊗Z1+Z1⊗X1)

show(out, MIME"text/html"(), reg1[1])
show(out, MIME"text/html"(), reg2[2])
show(out, MIME"text/html"(), QuantumSavory.stateof(reg1[1]))


reg1 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
reg2 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
net = RegisterNet([reg1, reg2]; name="my net", names=["reg 1", "reg 2"])

initialize!((reg1[1],reg2[1]), X1⊗Z1+Z1⊗X1)

show(out, MIME"text/html"(), reg1[1])
show(out, MIME"text/html"(), reg2[2])
show(out, MIME"text/html"(), QuantumSavory.stateof(reg1[1]))


prot = EntanglerProt(get_time_tracker(net), net, 1, 2)
show(out, MIME"text/html"(), prot)


reg1 = Register([Qumode()], [GabsRepr(QuadPairBasis)])
initialize!(reg1[1], CoherentState(0.2 - 0.5im))
apply!(reg1[1], DisplaceOp(0.6 - 0.4im))
html = sprint(show, MIME"text/html"(), QuantumSavory.stateof(reg1[1]))
@test !occursin("does not support rich visualization", html)


end
