@safetestset "colorcentermodularcluster" begin
    include("../examples/colorcentermodularcluster/1_time_to_connected.jl")
    if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true"
        include("../examples/colorcentermodularcluster/2_real_time_visualization.jl")
    end
end

@safetestset "congestionchain" begin
    if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true"
        include("../examples/congestionchain/1_visualization.jl")
    end
end

@safetestset "firstgenrepeater" begin
    if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true"
        include("../examples/firstgenrepeater/1_entangler_example.jl")
        include("../examples/firstgenrepeater/2_swapper_example.jl")
        include("../examples/firstgenrepeater/3_purifier_example.jl")
        include("../examples/firstgenrepeater/4_visualization.jl")
        include("../examples/firstgenrepeater/5_clifford_full_example.jl")
        include("../examples/firstgenrepeater/6_compare_formalisms.jl")
    end
    include("../examples/firstgenrepeater/6.1_compare_formalisms_noplot.jl")
end

@safetestset "firstgenrepeater_v2" begin
    if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true"
        include("../examples/firstgenrepeater_v2/1_entangler_example.jl")
        include("../examples/firstgenrepeater_v2/2_swapper_example.jl")
    end
end

@safetestset "simpleswitch" begin
    if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true"
        # TODO-MATCHING due to the dependence on BlossomV.jl this has trouble installing. See https://github.com/JuliaGraphs/GraphsMatching.jl/issues/14
        #include("../examples/simpleswitch/1_interactive_visualization.jl")
    end
end

@safetestset "repeatergrid" begin
    if get(ENV, "QUANTUMSAVORY_PLOT_TEST","")=="true"
        include("../examples/repeatergrid/1a_async_interactive_visualization.jl")
        include("../examples/repeatergrid/2a_sync_interactive_visualization.jl")
    end
end

if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true"
    import GLMakie
    GLMakie.closeall() # to avoid errors when running headless
end