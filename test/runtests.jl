using QuantumSavory
using TestItemRunner

function testfilter(tags)
    exclude = Symbol[]
    # Only do the plotting tests if the ENV variable `QUANTUMSAVORY_PLOT_TEST` is set
    if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")!="true"
        push!(exclude, :plotting_cairo)
        push!(exclude, :plotting_gl)
        push!(exclude, :examples_plotting)
        push!(exclude, :doctests)
    end
    if get(ENV,"JET_TEST","")!="true"
        push!(exclude, :jet)
    end
    return all(!in(exclude), tags)
end

if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true"
    include("setup_plotting.jl") # avoid the installation cost for GLMakie unless necessary
end

println("Starting tests with $(Threads.nthreads()) threads out of `Sys.CPU_THREADS = $(Sys.CPU_THREADS)`...")
@run_package_tests filter=ti->testfilter(ti.tags) verbose=true

if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true"
    import GLMakie
    GLMakie.closeall() # to avoid errors when running headless
end
