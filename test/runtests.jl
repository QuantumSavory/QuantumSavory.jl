using ParallelTestRunner

const TEST_PROJECTS = Dict(
    "plotting" => normpath(joinpath(@__DIR__, "projects", "plotting")),
    "examples" => normpath(joinpath(@__DIR__, "..", "examples")),
    "jet" => normpath(joinpath(@__DIR__, "projects", "jet")),
)

args = isempty(ARGS) ? ["general"] : ARGS
if isempty(ARGS)
    @info "No test arguments provided; defaulting to `general` tests."
elseif args == ["jet"]
    using Pkg
    Pkg.activate(TEST_PROJECTS["jet"])
    Pkg.instantiate()
end

test_project(name) = startswith(name, "plotting") ? TEST_PROJECTS["plotting"] :
                     startswith(name, "examples") ? TEST_PROJECTS["examples"] :
                     startswith(name, "jet") ? TEST_PROJECTS["jet"] :
                     nothing

project_init_code(project::String) = quote
    using Pkg
    Pkg.activate($project)
    if occursin("jet", $project) # The JET Project.toml is not included in the main Project.toml workspace because it frequently causes nightly tests to fail
        Pkg.instantiate()
    end

    using Logging # The examples generate a ton of logs
    logger = ConsoleLogger(Logging.Warn; meta_formatter=(args...)->(:black,"",""))
    global_logger(logger)
end

testsuite = find_tests(@__DIR__)
filter!(testsuite) do (name, _)
    endswith(name, "_tests")
end

if !isempty(VERSION.prerelease) || get(ENV, "QUANTUMSAVORY_DOWNGRADE_TEST", "") == "true"
    delete!(testsuite, "general/aqua_tests")
end

function test_worker(name)
    project = test_project(name)
    project === nothing && return nothing
    return addworker(; init_worker_code = project_init_code(project))
end

using QuantumSavory
runtests(QuantumSavory, args; testsuite, test_worker)
