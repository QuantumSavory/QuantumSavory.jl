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

@doset "circuitzoo_api"
@doset "circuitzoo_purification"
@doset "circuitzoo_superdense"

@doset "stateszoo_api"

@doset "examples"
get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true" && @doset "plotting_cairo"
get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true" && @doset "plotting_gl"
get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true" && VERSION >= v"1.9" && @doset "doctests"

get(ENV,"JET_TEST","")=="true" && @doset "jet"

using Aqua
using QuantumClifford, QuantumOptics, Graphs
doset("aqua") && begin
    Aqua.test_all(QuantumSavory,
                  ambiguities=false,
                  stale_deps=false, # TODO due to the package extensions being misidentified
                  piracies=false # TODO due to code that needs to be upstreamed
                  )
    #Aqua.test_ambiguities([QuantumSavory,Core]) # otherwise Base causes false positives
end
