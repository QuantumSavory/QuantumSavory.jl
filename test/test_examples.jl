using Logging
logger = ConsoleLogger(Logging.Warn; meta_formatter=(args...)->(:black,"",""))

with_logger(logger) do

@testitem "Examples - colorcentermodularcluster 1" tags=[:examples_plotting] begin
using Test
using QuantumSavory
    include("../examples/colorcentermodularcluster/1_time_to_connected.jl")
end

@testitem "Examples - colorcentermodularcluster 2" tags=[:examples_plotting] begin
using Test
using QuantumSavory
    include("../examples/colorcentermodularcluster/2_real_time_visualization.jl")
end

@testitem "Examples - congestionchain" tags=[:examples_plotting] begin
using Test
using QuantumSavory
    include("../examples/congestionchain/1_visualization.jl")
end

@testitem "Examples - firstgenrepeater 1" tags=[:examples_plotting] begin
using Test
using QuantumSavory
    include("../examples/firstgenrepeater/1_entangler_example.jl")
end
@testitem "Examples - firstgenrepeater 2" tags=[:examples_plotting] begin
using Test
using QuantumSavory
    include("../examples/firstgenrepeater/2_swapper_example.jl")
end
@testitem "Examples - firstgenrepeater 3" tags=[:examples_plotting] begin
using Test
using QuantumSavory
    include("../examples/firstgenrepeater/3_purifier_example.jl")
end
@testitem "Examples - firstgenrepeater 4" tags=[:examples_plotting] begin
using Test
using QuantumSavory
    include("../examples/firstgenrepeater/4_visualization.jl")
end
@testitem "Examples - firstgenrepeater 5" tags=[:examples_plotting] begin
using Test
using QuantumSavory
    include("../examples/firstgenrepeater/5_clifford_full_example.jl")
end
@testitem "Examples - firstgenrepeater 6" tags=[:examples_plotting] begin
using Test
using QuantumSavory
    include("../examples/firstgenrepeater/6_compare_formalisms.jl")
end
@testitem "Examples - firstgenrepeater 6.1" tags=[:examples] begin
using Test
using QuantumSavory
    include("../examples/firstgenrepeater/6.1_compare_formalisms_noplot.jl")
end

@testitem "Examples - firstgenrepeater_v2 1" tags=[:examples_plotting] begin
using Test
using QuantumSavory
    include("../examples/firstgenrepeater_v2/1_entangler_example.jl")
end
@testitem "Examples - firstgenrepeater_v2 2" tags=[:examples_plotting] begin
using Test
using QuantumSavory
    include("../examples/firstgenrepeater_v2/2_swapper_example.jl")
end

@testitem "Examples - simpleswitch" tags=[:examples_plotting] begin
using Test
using QuantumSavory
    include("../examples/simpleswitch/1_interactive_visualization.jl")
end

@safetestset "Examples - repeatergrid 1a" tags=[:examples_plotting] begin
    include("../examples/repeatergrid/1a_async_interactive_visualization.jl")
end
@safetestset "Examples - repeatergrid 2a" tags=[:examples_plotting] begin
    include("../examples/repeatergrid/2a_sync_interactive_visualization.jl")
end

end # with_logger
