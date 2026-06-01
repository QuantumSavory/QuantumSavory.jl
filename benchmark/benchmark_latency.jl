SUITE["latency"] = BenchmarkGroup(["latency"])
SUITE["latency"]["import"] = BenchmarkGroup(["import"])

const IMPORT_QUANTUMSAVORY_SNIPPET = "using QuantumSavory; @assert isdefined(Main, :QuantumSavory)"

function import_quantumsavory_fresh_process()
    project = dirname(Base.active_project())
    cmd = `$(Base.julia_cmd()) --startup-file=no --project=$project -e $IMPORT_QUANTUMSAVORY_SNIPPET`
    return success(pipeline(cmd; stdout=devnull, stderr=devnull))
end

# Track package load latency in a clean Julia process.  Keep the sample count
# intentionally low because this benchmark launches a subprocess each time.
SUITE["latency"]["import"]["fresh_process"] = @benchmarkable import_quantumsavory_fresh_process() evals=1 samples=3 seconds=120
