using QuantumSavory
using TestItemRunner

function testfilter(tags)
    exclude = Symbol[]
    # Only do the plotting tests if the ENV variable `QUANTUMSAVORY_PLOT_TEST` is set
    if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")!="true"
        push!(exclude, :plotting_cairo)
        push!(exclude, :plotting_gl)
        if VERSION >= v"1.9"
            push!(exclude, :doctests)
        end
    end
    if get(ENV,"JET_TEST","")!="true"
        push!(exclude, :jet)
    end
    return all(!in(exclude), tags)
end

println("Starting tests with $(Threads.nthreads()) threads out of `Sys.CPU_THREADS = $(Sys.CPU_THREADS)`...")

@run_package_tests filter=ti->testfilter(ti.tags)