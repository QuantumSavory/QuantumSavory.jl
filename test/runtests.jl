using QuantumSavory
using TestItems
using TestItemRunner

function doset(tag)
    if length(ARGS) == 0
        return true
    end
    for a in ARGS
        if occursin(lowercase(a), lowercase(String(tag)))
            return true
        end
    end
    if get(ENV,"JET_TEST","")=="true" && tag == :jet
        return true
    end
    if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true"
        if tag in [:plotting_gl, :plotting_cairo]
            return true
        end
        if VERSION >= v"1.9" && tag == :doctests
            return true
        end
    end
    if tag in [:examples, :aqua]
        return true
    end

    return false
end

println("Starting tests with $(Threads.nthreads()) threads out of `Sys.CPU_THREADS = $(Sys.CPU_THREADS)`...")

if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true"
    using Pkg
    Pkg.add("GLMakie")
end

@run_package_tests filter=ti->any([doset(tag) for tag in ti.tags])
