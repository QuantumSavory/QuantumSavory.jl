using QuantumSavory
using ParallelTestRunner

const TEST_PROJECTS = Dict(
    "plotting" => normpath(joinpath(@__DIR__, "projects", "plotting")),
    "example" => normpath(joinpath(@__DIR__, "projects", "examples")),
    "jet" => normpath(joinpath(@__DIR__, "projects", "jet")),
)

test_project(name) = startswith(name, "plotting/") ? TEST_PROJECTS["plotting"] :
                     startswith(name, "example/") ? TEST_PROJECTS["example"] :
                     startswith(name, "jet") ? TEST_PROJECTS["jet"] :
                     nothing

project_init_code(project::String) = quote
    using Pkg
    Pkg.activate($project)
end

testsuite = find_tests(@__DIR__)
filter!(testsuite) do (name, _)
    endswith(name, "_tests")
end

if get(ENV, "QUANTUMSAVORY_DOWNGRADE_TEST", "") == "true"
    delete!(testsuite, "general/aqua_tests")
end

function test_worker(name)
    project = test_project(name)
    project === nothing && return nothing
    return addworker(; init_worker_code = project_init_code(project))
end

runtests(QuantumSavory, ARGS; testsuite, test_worker)
