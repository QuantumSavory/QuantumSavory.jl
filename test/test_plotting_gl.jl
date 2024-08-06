@testitem "Plotting GL" tags=[:plotting_gl] begin
    include("setup_plotting.jl")
    using GLMakie
    GLMakie.activate!()

    @testset "register coordinates" begin
        include("test_plotting_1_regcoords.jl")
    end
    @testset "arguments and observables and tags" begin
        include("test_plotting_2_tags_observables.jl")
    end
end

using QuantumSavory

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
    @test Base.get_extension(QuantumSavory, :QuantumSavoryMakie).get_state_vis_string(plt.state_coords_backref[],1) == "Subsystem 1 of a state of 1 subsystems, stored in\nRegister 1 | Slot 1\n not tagged"
end
