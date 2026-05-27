using Test

@testset "Examples - percolation lattice" begin
    include("../../examples/percolation_lattice/setup.jl")

    graph = square_lattice_graph(3)
    @test nv(graph) == 9
    @test ne(graph) == 12
    @test has_edge(graph, node_index(3, 1, 1), node_index(3, 1, 2))
    @test has_edge(graph, node_index(3, 1, 1), node_index(3, 2, 1))

    always_connected = run_percolation_trial(; n=3, link_success=1.0, seed=42)
    @test always_connected.connected
    @test always_connected.selected_path[1] == 1
    @test always_connected.selected_path[end] == 9
    @test always_connected.path_hops == 4
    @test always_connected.estimated_fidelity ≈
          swapped_path_fidelity(always_connected.link_fidelity, 4;
              swap_visibility=always_connected.swap_visibility)

    never_connected = run_percolation_trial(; n=3, link_success=0.0, seed=42)
    @test !never_connected.connected
    @test never_connected.selected_path == Int[]
    @test never_connected.path_hops == 0
    @test isnothing(never_connected.estimated_fidelity)

    ensemble = run_percolation_ensemble(; n=3, link_success=1.0, samples=5, seed=7)
    @test ensemble.connected_count == 5
    @test ensemble.success_rate == 1.0
    @test ensemble.mean_path_hops == 4
    @test isfinite(ensemble.mean_estimated_fidelity)

    @test percolation_register_net(3).graph == graph
end
