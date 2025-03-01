using FileIO
using GeoMakie
using QuantumSavory

sizes = [2,3,5]
registers = Register[]
for s in sizes
    traits = [Qubit() for _ in 1:s]
    bg = [T2Dephasing(1.0) for _ in 1:s]
    push!(registers, Register(traits,bg))
end
network = RegisterNet(registers)
map_axis = generate_map()
coords = [Point2f(-71, 42), Point2f(-111, 34), Point2f(-122, 37)]
_, _, plt, netobs = registernetplot_axis(map_axis, network, registercoords=coords)
save(File{format"PNG"}(mktemp()[1]), fig)

initialize!(network[1,1])
initialize!(network[2,1])
notify(netobs)
save(File{format"PNG"}(mktemp()[1]), fig)

apply!([network[1,1],network[2,1]], CNOT)
notify(netobs)
save(File{format"PNG"}(mktemp()[1]), fig)

display(fig)

fig = Figure()
map_axis = generate_map(fig[1, 1])
_, _, plt, netobs = registernetplot_axis(map_axis, network, registercoords=coords)
save(File{format"PNG"}(mktemp()[1]), fig)
