using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo
using CairoMakie
import InteractiveUtils, REPL

@testset "show image/png" begin

#out = stdout
out = IOBuffer()
png_signature = UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]

function show_png_bytes(x)
    io = IOBuffer()
    show(io, MIME"image/png"(), x)
    take!(io)
end

reg = Register([Qubit(), Qumode()], [CliffordRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])

initialize!(reg[1], X1)

#show(out, MIME"image/png"(), reg[1])
#show(out, MIME"image/png"(), reg[2])
show(out, MIME"image/png"(), QuantumSavory.stateof(reg[1]))
clifford_png = show_png_bytes(QuantumSavory.stateof(reg[1]))
@test length(clifford_png) > 1000
@test clifford_png[1:8] == png_signature

qoreg = Register([Qubit()], [QuantumOpticsRepr()])
initialize!(qoreg[1], X1)
qo_png = show_png_bytes(QuantumSavory.stateof(qoreg[1]))
@test length(qo_png) > 1000
@test qo_png[1:8] == png_signature

qoref = QuantumSavory.stateof(qoreg[1])
zero_operator = 0 * QuantumSavory.dm(QuantumSavory.quantumstate(qoref))
makie_ext = Base.get_extension(QuantumSavory, :QuantumSavoryMakie)
@test !isnothing(makie_ext)
zero_operator_fig = Figure(size=(360, 240))
makie_ext.stateshowimage(zero_operator_fig[1,1], zero_operator, qoref)
zero_operator_png = show_png_bytes(zero_operator_fig)
@test length(zero_operator_png) > 1000
@test zero_operator_png[1:8] == png_signature

reg1 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
reg2 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
net = RegisterNet([reg1, reg2])

initialize!((reg1[1],reg2[1]), X1⊗Z1+Z1⊗X1)

#show(out, MIME"image/png"(), reg1[1])
#show(out, MIME"image/png"(), reg2[2])
show(out, MIME"image/png"(), QuantumSavory.stateof(reg1[1]))
twoqubit_png = show_png_bytes(QuantumSavory.stateof(reg1[1]))
@test length(twoqubit_png) > 1000
@test twoqubit_png[1:8] == png_signature


reg1 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
reg2 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
net = RegisterNet([reg1, reg2]; name="my net", names=["reg 1", "reg 2"])

initialize!((reg1[1],reg2[1]), X1⊗Z1+Z1⊗X1)

#show(out, MIME"image/png"(), reg1[1])
#show(out, MIME"image/png"(), reg2[2])
show(out, MIME"image/png"(), QuantumSavory.stateof(reg1[1]))


prot = EntanglerProt(get_time_tracker(net), net, 1, 2)
show(out, MIME"image/png"(), prot)

end
