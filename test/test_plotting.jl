using Test
using CairoMakie
using FileIO
using QuantumSavory

sizes = [2,3,2]
registers = Register[]
for s in sizes
    traits = [Qubit() for _ in 1:s]
    bg = [T2Dephasing(1.0) for _ in 1:s]
    push!(registers, Register(traits,bg))
end
network = RegisterNet(registers)

fig = Figure(resolution=(400,400))
subfig_rg, ax_rg, obs = registernetplot_axis(fig[1,1],network)
save(File{format"PNG"}(mktemp()[1]), fig)

initialize!(network[1,1])
initialize!(network[2,1])
notify(obs[1])
save(File{format"PNG"}(mktemp()[1]), fig)

apply!([network[1,1],network[2,1]], CNOT)
notify(obs[1])
save(File{format"PNG"}(mktemp()[1]), fig)
