using BenchmarkTools

SUITE["examples"] = BenchmarkGroup(["examples"])

examples_path = joinpath(@__DIR__, "..", "examples")
if isdir(examples_path)
    example_dirs = filter(isdir, readdir(examples_path, join=true))
    for dir in example_dirs
        jl_files = filter(f -> endswith(f, ".jl") && !startswith(basename(f), "setup"), readdir(dir))
        for jl_file in jl_files
            name = basename(dir) * "/" * jl_file
            path = joinpath(dir, jl_file)
            # Use samples=1 and evals=1 because examples can take a long time to run and include julia compilation
            SUITE["examples"][name] = @benchmarkable run(`julia --project=$(joinpath(@__DIR__, "..")) -e "include(\\"$path\\")"`) samples=1 evals=1
        end
    end
end
