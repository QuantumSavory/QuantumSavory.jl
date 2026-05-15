using QuantumSavory
using Test
using GLMakie
GLMakie.activate!()

@testset "Plotting GL" begin
@testset "register coordinates" begin
    include("plotting_regcoords.jl")
end
@testset "arguments and observables and tags" begin
    include("plotting_tags_observables.jl")
end
@testset "background map" begin
    include("plotting_maps.jl")
end

@testset "data inspectors" begin # only available in GLMakie
    # create a network of qubit registers
    net = RegisterNet([Register(2),Register(3),Register(2),Register(5)])

    # add some states, entangle a few slots, perform some gates
    initialize!(net[1,1])
    initialize!(net[2,3], X₁)
    initialize!((net[3,1],net[4,2]), X₁⊗Z₂)
    apply!((net[2,3],net[3,1]), CNOT)

    # create the plot
    fig = Figure(size=(800,400))
    _, ax, plt, obs = registernetplot_axis(fig[1,1],net)

    # check the data inspector tooltip functionality
    backref = plt._extras[][:state_coords_backref][]
    makie_extension = Base.get_extension(QuantumSavory, :QuantumSavoryMakie)
    tooltip = makie_extension.get_state_vis_string(backref,1)
    @test occursin("Subsystem 1 of a state of 1 subsystems", tooltip)
    @test occursin("State: $(makie_extension.state_summary(backref[1][1]))", tooltip)
    @test occursin("Stored in Register 1 | Slot 1", tooltip)
    @test occursin("not tagged", tooltip)
end
end

GLMakie.closeall()
