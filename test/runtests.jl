using Pkg

if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")!="true"
    @info "skipping plotting tests"
else
    Pkg.add(["GLMakie", "CairoMakie", "NetworkLayout", "Tyler", "Makie"])
end

if get(ENV,"QUANTUMSAVORY_EXAMPLES_TEST","")!="true"
    @info "skipping examples tests"
else
    Pkg.add(["GLMakie", "CairoMakie", "NetworkLayout", "Tyler", "Makie"])
end

if get(ENV,"JET_TEST","")!="true"
    @info "skipping JET tests"
else
    Pkg.add("JET")
end

using QuantumSavory
using ParallelTestRunner

# Discover tests and filter to only _tests files
testsuite = find_tests(@__DIR__)
filter!(testsuite) do (name, _)
    endswith(name, "_tests")
end

# Define test categories
plotting_names = ["plotting_cairo_tests", "plotting_gl_tests", "show_png_tests", "doctests_tests"]
examples_names = [name for name in keys(testsuite) if startswith(name, "examples_")]
jet_names = ["jet_tests"]

# When a specialized ENV var is set, run ONLY those tests
if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true"
    filter!(testsuite) do (name, _)
        name in plotting_names
    end
elseif get(ENV,"QUANTUMSAVORY_EXAMPLES_TEST","")=="true"
    filter!(testsuite) do (name, _)
        name in examples_names
    end
elseif get(ENV,"JET_TEST","")=="true"
    filter!(testsuite) do (name, _)
        name in jet_names
    end
else
    # Default: exclude all specialized tests
    for name in [plotting_names; examples_names; jet_names]
        delete!(testsuite, name)
    end
    if get(ENV,"QUANTUMSAVORY_DOWNGRADE_TEST","")=="true"
        delete!(testsuite, "aqua_tests")
    end
end

println("Starting tests on `Sys.CPU_THREADS = $(Sys.CPU_THREADS)`...")
runtests(QuantumSavory, ARGS; testsuite)

if get(ENV,"QUANTUMSAVORY_PLOT_TEST","")=="true"
    import GLMakie
    GLMakie.closeall() # to avoid errors when running headless
end
