using Test, Random

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

println("Starting tests with $(Threads.nthreads()) threads out of `Sys.CPU_THREADS = $(Sys.CPU_THREADS)`...")

doset("doctests")           && VERSION == v"1.7" && include("doctests.jl")

using Aqua
doset("aqua") && Aqua.test_all(QuantumSavory)
