using SafeTestsets
using QuantumSavory

function doset(descr)
    if length(ARGS) == 0
        return true
    end
    for a in ARGS
        if occursin(lowercase(a), lowercase(descr))
            return true
        end
    end
    return false
end

macro doset(descr)
    quote
        if doset($descr)
            @safetestset $descr begin include("test_"*$descr*".jl") end
        end
    end
end

println("Starting tests with $(Threads.nthreads()) threads out of `Sys.CPU_THREADS = $(Sys.CPU_THREADS)`...")

@doset "quantumchannel"
@doset "register_interface"
@doset "project_traceout"
@doset "observable"
@doset "noninstant_and_backgrounds_qubit"
@doset "noninstant_and_backgrounds_qumode"
@doset "messagebuffer"
@doset "tags_and_queries"

@doset "protocolzoo_entanglement_tracker"
@doset "protocolzoo_entanglement_consumer"
@doset "protocolzoo_entanglement_tracker_grid"
@doset "protocolzoo_switch"
@doset "protocolzoo_throws"

@doset "circuitzoo_api"
@doset "circuitzoo_ent_swap"
@doset "circuitzoo_purification"
@doset "circuitzoo_superdense"

@doset "stateszoo_api"

if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true"
    using Pkg
    Pkg.add("GLMakie")
end
@doset "examples"
get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true" && @doset "plotting_cairo"
get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true" && @doset "plotting_gl"
get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true" && VERSION >= v"1.9" && @doset "doctests"

get(ENV,"JET_TEST","")=="true" && @doset "jet"
@doset "aqua"