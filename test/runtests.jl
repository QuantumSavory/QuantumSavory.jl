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
using ParallelTestRunner

# Discover tests and filter to only _tests files
testsuite = find_tests(@__DIR__)
filter!(testsuite) do (name, _)
    endswith(name, "_tests")
end

# ENV-based filtering
if get(ENV,"QUANTUMSAVORY_DOWNGRADE_TEST","")=="true"
    delete!(testsuite, "test_aqua_tests")
end
if get(ENV,"JET_TEST","")!="true"
    delete!(testsuite, "test_jet_tests")
end

println("Starting tests with $(Threads.nthreads()) threads out of `Sys.CPU_THREADS = $(Sys.CPU_THREADS)`...")
runtests(QuantumSavory, ARGS; testsuite)
