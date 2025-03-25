@testitem "Examples - colorcentermodularcluster 1" tags=[:examples] begin
    include("../examples/colorcentermodularcluster/1_time_to_connected.jl")
end

@testitem "Examples - colorcentermodularcluster 2" tags=[:examples_plotting] begin
    include("../examples/colorcentermodularcluster/2_real_time_visualization.jl")
end

@testitem "Examples - congestionchain" tags=[:examples_plotting] begin
    include("../examples/congestionchain/1_visualization.jl")
end

@testitem "Examples - firstgenrepeater 1" tags=[:examples_plotting] begin
    include("../examples/firstgenrepeater/1_entangler_example.jl")
end
@testitem "Examples - firstgenrepeater 2" tags=[:examples_plotting] begin
    include("../examples/firstgenrepeater/2_swapper_example.jl")
end
@testitem "Examples - firstgenrepeater 3" tags=[:examples_plotting] begin
    include("../examples/firstgenrepeater/3_purifier_example.jl")
end
@testitem "Examples - firstgenrepeater 4" tags=[:examples_plotting] begin
    include("../examples/firstgenrepeater/4_visualization.jl")
end
@testitem "Examples - firstgenrepeater 5" tags=[:examples_plotting] begin
    include("../examples/firstgenrepeater/5_clifford_full_example.jl")
end
@testitem "Examples - firstgenrepeater 6" tags=[:examples_plotting] begin
    include("../examples/firstgenrepeater/6_compare_formalisms.jl")
end
@testitem "Examples - firstgenrepeater 6.1" tags=[:examples] begin
    include("../examples/firstgenrepeater/6.1_compare_formalisms_noplot.jl")
end

@testitem "Examples - firstgenrepeater_v2 1" tags=[:examples_plotting] begin
    include("../examples/firstgenrepeater_v2/1_entangler_example.jl")
end
@testitem "Examples - firstgenrepeater_v2 2" tags=[:examples_plotting] begin
    include("../examples/firstgenrepeater_v2/2_swapper_example.jl")
end

@testitem "Examples - simpleswitch" tags=[:examples_plotting] begin
    # TODO-MATCHING due to the dependence on BlossomV.jl this has trouble installing. See https://github.com/JuliaGraphs/GraphsMatching.jl/issues/14
    include("../examples/simpleswitch/1_interactive_visualization.jl")
end

@safetestset "Examples - repeatergrid 1a" tags=[:examples_plotting] begin
    include("../examples/repeatergrid/1a_async_interactive_visualization.jl")
end
@safetestset "Examples - repeatergrid 2a" tags=[:examples_plotting] begin
    include("../examples/repeatergrid/2a_sync_interactive_visualization.jl")
end
