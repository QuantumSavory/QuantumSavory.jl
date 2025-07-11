using Pkg

if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")!="true"
    @info "skipping plotting tests"
else
    Pkg.add(["GLMakie", "CairoMakie", "NetworkLayout", "Tyler", "Makie"])
end

if get(ENV,"QUANTUMSAVORY_EXAMPLES_PLOT_TEST","")!="true"
    @info "skipping examples with plotting tests"
else
    Pkg.add(["GLMakie", "CairoMakie", "NetworkLayout", "Tyler", "Makie"])
end

if get(ENV,"QUANTUMSAVORY_EXAMPLES_TEST","")!="true"
    @info "skipping examples without plotting tests"
else
end

if get(ENV,"JET_TEST","")!="true"
    @info "skipping JET tests"
else
    Pkg.add("JET")
end

using QuantumSavory
using TestItemRunner

function testfilter(tags)
    exclude = Symbol[]
    if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")!="true"
        push!(exclude, :plotting_cairo)
        push!(exclude, :plotting_gl)
        push!(exclude, :doctests)
    else
        return :plotting_cairo in tags || :plotting_gl in tags || :examples_plotting in tags || :doctests in tags
    end

    if get(ENV,"QUANTUMSAVORY_EXAMPLES_PLOT_TEST","")!="true"
        push!(exclude, :examples_plotting)
    else
        return :examples_plotting in tags
    end

    if get(ENV,"QUANTUMSAVORY_EXAMPLES_TEST","")!="true"
        push!(exclude, :examples)
    else
        return :examples in tags
    end

    if get(ENV,"JET_TEST","")!="true"
        push!(exclude, :jet)
    else
        return :jet in tags
    end

    return all(!in(exclude), tags)
end


println("Starting tests with $(Threads.nthreads()) threads out of `Sys.CPU_THREADS = $(Sys.CPU_THREADS)`...")
@run_package_tests filter=ti->testfilter(ti.tags) verbose=true

if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true"
    import GLMakie
    GLMakie.closeall() # to avoid errors when running headless
end
