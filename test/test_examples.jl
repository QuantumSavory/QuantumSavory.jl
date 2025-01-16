@testitem "Examples - colorcentermodularcluster" tags=[:examples] begin
    include("../examples/colorcentermodularcluster/1_time_to_connected.jl")
    if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true"
        include("../examples/colorcentermodularcluster/2_real_time_visualization.jl")
    end
end

@testitem "Examples - congestionchain" tags=[:examples] begin
    if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true"
        include("setup_plotting.jl")
        include("../examples/congestionchain/1_visualization.jl")
    end
end

@testitem "Examples - firstgenrepeater" tags=[:examples] begin
    if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true"
        include("setup_plotting.jl")
        include("../examples/firstgenrepeater/1_entangler_example.jl")
        include("../examples/firstgenrepeater/2_swapper_example.jl")
        include("../examples/firstgenrepeater/3_purifier_example.jl")
        include("../examples/firstgenrepeater/4_visualization.jl")
        include("../examples/firstgenrepeater/5_clifford_full_example.jl")
        include("../examples/firstgenrepeater/6_compare_formalisms.jl")
    end
    include("../examples/firstgenrepeater/6.1_compare_formalisms_noplot.jl")
end

@testitem "Examples - firstgenrepeater_v2" tags=[:examples] begin
    if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true"
        include("setup_plotting.jl")
        include("../examples/firstgenrepeater_v2/1_entangler_example.jl")
        include("../examples/firstgenrepeater_v2/2_swapper_example.jl")
    end
end

@testitem "Examples - simpleswitch" tags=[:examples] begin
    if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true"
        # TODO-MATCHING due to the dependence on BlossomV.jl this has trouble installing. See https://github.com/JuliaGraphs/GraphsMatching.jl/issues/14
        #include("setup_plotting.jl")
        #include("../examples/simpleswitch/1_interactive_visualization.jl")
    end
end

@testitem "Examples - repeatergrid" tags=[:examples] begin
    if get(ENV, "QUANTUMSAVORY_PLOT_TEST","")=="true"
        include("setup_plotting.jl")
        include("../examples/repeatergrid/1a_async_interactive_visualization.jl")
        include("../examples/repeatergrid/2a_sync_interactive_visualization.jl")
    end
end

@testitem "Examples - controlplane" tags=[:examples] begin
    if get(ENV, "QUANTUMSAVORY_PLOT_TEST","")=="true"
        include("../examples/controlplane/1a_cdd_interactive.jl")
        include("../examples/controlplane/2a_cnc_interactive.jl")
    end
end

if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true"
    import GLMakie
    GLMakie.closeall() # to avoid errors when running headless
end
