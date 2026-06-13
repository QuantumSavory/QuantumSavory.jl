using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo

@testset "show text/html" begin

#out = stdout
out = IOBuffer()

reg = Register([Qubit(), Qumode()], [CliffordRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])

initialize!(reg[1], X1)

show(out, MIME"text/html"(), reg[1])
show(out, MIME"text/html"(), reg[2])
show(out, MIME"text/html"(), QuantumSavory.stateof(reg[1]))
clifford_text = sprint(show, QuantumSavory.stateof(reg[1]))
clifford_html = sprint(show, MIME"text/html"(), QuantumSavory.stateof(reg[1]))
@test occursin("QuantumClifford MixedDestabilizer", clifford_text)
@test occursin("QuantumClifford stabilizer summary", clifford_html)
@test !occursin("does not support rich visualization in HTML", clifford_html)

qoreg = Register([Qubit()], [QuantumOpticsRepr()])
initialize!(qoreg[1], X1)
qo_text = sprint(show, QuantumSavory.stateof(qoreg[1]))
qo_html = sprint(show, MIME"text/html"(), QuantumSavory.stateof(qoreg[1]))
@test occursin("QuantumOpticsBase", qo_text)
@test occursin("Bloch vector / Pauli expectations", qo_text)
@test occursin("QuantumOpticsBase state summary", qo_html)
@test occursin("Pauli", qo_html)
@test !occursin("does not support rich visualization in HTML", qo_html)

reg1 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
reg2 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
net = RegisterNet([reg1, reg2])

initialize!((reg1[1],reg2[1]), X1⊗Z1+Z1⊗X1)

show(out, MIME"text/html"(), reg1[1])
show(out, MIME"text/html"(), reg2[2])
show(out, MIME"text/html"(), QuantumSavory.stateof(reg1[1]))
twoqubit_html = sprint(show, MIME"text/html"(), QuantumSavory.stateof(reg1[1]))
@test occursin("Pauli correlations", twoqubit_html)
@test occursin("density_matrix", twoqubit_html)
@test !occursin("does not support rich visualization in HTML", twoqubit_html)


reg1 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
reg2 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
net = RegisterNet([reg1, reg2]; name="my net", names=["reg 1", "reg 2"])

initialize!((reg1[1],reg2[1]), X1⊗Z1+Z1⊗X1)

show(out, MIME"text/html"(), reg1[1])
show(out, MIME"text/html"(), reg2[2])
show(out, MIME"text/html"(), QuantumSavory.stateof(reg1[1]))


prot = EntanglerProt(get_time_tracker(net), net, 1, 2)
show(out, MIME"text/html"(), prot)

end
