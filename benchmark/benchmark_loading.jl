SUITE["loading"] = BenchmarkGroup(["loading"])

# Measure a fresh Julia process importing QuantumSavory. This tracks precompile
# and dependency-loading regressions separately from the in-process benchmarks.
function quantum_savory_import_smoke()
    julia = Base.julia_cmd()
    project_dir = dirname(Base.active_project())
    cmd = `$julia --startup-file=no --project=$project_dir -e 'using QuantumSavory'`
    run(cmd)
    return nothing
end

SUITE["loading"]["import"] = BenchmarkGroup(["import"])
SUITE["loading"]["import"]["fresh_process"] = @benchmarkable quantum_savory_import_smoke() samples=1 evals=1 seconds=60
