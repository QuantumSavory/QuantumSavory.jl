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
qoref = QuantumSavory.stateof(qoreg[1])
qo_state = QuantumSavory.quantumstate(qoref)
qo_text = sprint(show, qoref)
qo_html = sprint(show, MIME"text/html"(), qoref)
@test occursin("QuantumOpticsBase", qo_text)
@test occursin("Bloch vector / Pauli expectations", qo_text)
@test occursin("QuantumOpticsBase state summary", qo_html)
@test occursin("Pauli", qo_html)
@test !occursin("does not support rich visualization in HTML", qo_html)

qo_op = QuantumSavory.dm(qo_state)
qo_op_text = sprint(QuantumSavory.stateshowtext, qo_op, qoref)
qo_op_html = sprint(QuantumSavory.stateshow, MIME"text/html"(), qo_op, qoref)
@test occursin("backend: QuantumOpticsBase Operator", qo_op_text)
@test occursin("QuantumOpticsBase state summary", qo_op_html)
@test occursin("quantumsavory_density_matrix", qo_op_html)

fallback_html = sprint(QuantumSavory.stateshow, MIME"text/html"(), "unsupported", qoref)
@test occursin("does not support rich visualization in HTML", fallback_html)

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

big = Register([Qubit() for _ in 1:6], [QuantumOpticsRepr() for _ in 1:6])
initialize!(
    Tuple(big[i] for i in 1:6),
    reduce(⊗, [X1 for _ in 1:6]) + reduce(⊗, [Z1 for _ in 1:6]),
)
bigref = QuantumSavory.stateof(big[1])
big_text = sprint(show, bigref)
big_html = sprint(show, MIME"text/html"(), bigref)
@test occursin("dimension 64 exceeds", big_text)
@test occursin("Density matrix omitted for dimension 64", big_html)
@test occursin("top probabilities", big_text)


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
