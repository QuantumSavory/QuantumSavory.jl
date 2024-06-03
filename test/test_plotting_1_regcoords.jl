using Test
#using CairoMakie
#using GLMakie
using FileIO
using QuantumSavory

sizes = [2,3,2,5,6,2,3]
registers = Register[]
for s in sizes
    traits = [Qubit() for _ in 1:s]
    bg = [T2Dephasing(1.0) for _ in 1:s]
    push!(registers, Register(traits,bg))
end
network = RegisterNet(registers)

fig = Figure(size=(400,400))
_, _, plt, netobs = registernetplot_axis(fig[1,1],network)
save(File{format"PNG"}(mktemp()[1]), fig)

initialize!(network[1,1])
initialize!(network[2,1])
notify(netobs)
save(File{format"PNG"}(mktemp()[1]), fig)

apply!([network[1,1],network[2,1]], CNOT)
notify(netobs)
save(File{format"PNG"}(mktemp()[1]), fig)

display(fig)

##

using Graphs
using ConcurrentSim
sim = Simulation()
for v in vertices(network)
    network[v,:bool] = rand(Bool)
    network[v,:resource] = Resource(sim,1)
    rand(Bool) && request(network[v,:resource])
end
for e in edges(network)
    network[e,:bool] = true
    network[e,:bool2] = rand(Bool)
end
fig2 = Figure(size=(400,400))
_,_,_,netobs2 = resourceplot_axis(fig2[1,1],network,[:bool,:bool2],[:bool,:resource]; registercoords=plt[:registercoords])
display(fig2)
fig3 = Figure(size=(400,400))
_,_,_,netobs3 = resourceplot_axis(fig3[1,1],network,[:bool,:bool2],[:bool,:resource])
display(fig3)

##

for e in edges(network)
    network[e,:bool] = false
    network[e,:bool2] = true
end
notify(netobs3)
display(fig3)
