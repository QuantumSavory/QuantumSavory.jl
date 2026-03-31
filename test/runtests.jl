using Pkg

const TEST_PROJECTS = Dict(
    "plotting" => normpath(joinpath(@__DIR__, "projects", "plotting")),
    "examples" => normpath(joinpath(@__DIR__, "..", "examples")),
    "jet" => normpath(joinpath(@__DIR__, "projects", "jet")),
)

requested_suites(args::Vector{String}) = filter(args) do arg
    !startswith(arg, "-") && !all(isdigit, arg)
end

function jet_only_request(args::Vector{String})
    suites = requested_suites(args)
    return !isempty(suites) && all(startswith("jet"), suites)
end

function copy_package_for_jet!(src::String, dst::String)
    mkpath(dst)
    for entry in ("Project.toml", "CondaPkg.toml", "src", "ext")
        src_entry = joinpath(src, entry)
        ispath(src_entry) || continue
        cp(src_entry, joinpath(dst, entry); force=true)
    end
    return dst
end

function run_jet_in_clean_env()
    package_root = normpath(joinpath(@__DIR__, ".."))
    package_copy_root = mktempdir()
    # Avoid inheriting the development workspace manifest, which may pin local sibling paths.
    package_copy = copy_package_for_jet!(package_root, joinpath(package_copy_root, "QuantumSavory.jl"))

    Pkg.activate(; temp=true)
    Pkg.develop(path=package_copy)
    Pkg.add(name="JET")

    include(joinpath(@__DIR__, "jet_tests.jl"))
    return nothing
end

if isempty(ARGS)
    @info "No test arguments provided; defaulting to `general` tests."
end
args = isempty(ARGS) ? ["general"] : copy(ARGS)
if jet_only_request(args)
    run_jet_in_clean_env()
    exit()
end

using QuantumSavory
using ParallelTestRunner

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

runtests(QuantumSavory, args; testsuite, test_worker)
