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

@doset "plotting"
VERSION == v"1.7" && @doset "doctests"

using Aqua
using QuantumClifford, QuantumOptics, Graphs
doset("aqua") && begin
    Aqua.test_all(QuantumSavory, ambiguities=false)
    #Aqua.test_ambiguities([QuantumSavory,QuantumClifford,QuantumOptics,Graphs,Core]) # otherwise Base causes false positives
end
