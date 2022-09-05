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
doset("aqua") && Aqua.test_all(QuantumSavory)
