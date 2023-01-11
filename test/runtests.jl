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

@doset "register_interface"
@doset "noninstant"
@doset "examples"
get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true" && @doset "plotting_cairo"
get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true" && @doset "plotting_gl"
get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true" && VERSION == v"1.8" && @doset "doctests"
get(ENV,"QUANTUMSAVORY_JET_TEST","")=="true" && @doset "jet"

using Aqua
using QuantumClifford, QuantumOptics, Graphs
doset("aqua") && begin
    Aqua.test_all(QuantumSavory,
                  ambiguities=false,
                  stale_deps=false # TODO due to the package extensions being misidentified
                  )
    #Aqua.test_ambiguities([QuantumSavory,Core]) # otherwise Base causes false positives
end
