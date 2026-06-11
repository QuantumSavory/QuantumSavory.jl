SUITE["imports"] = BenchmarkGroup(["imports"])

function _run_import_expression(expr::AbstractString)
    project = dirname(Base.active_project())
    cmd = `$(Base.julia_cmd()) --startup-file=no --project=$(project) -e $(expr)`
    run(pipeline(cmd; stdout=devnull, stderr=devnull))
    return nothing
end

function import_quantumsavory()
    _run_import_expression("using QuantumSavory")
end

function import_protocolzoo()
    _run_import_expression("using QuantumSavory; using QuantumSavory.ProtocolZoo")
end

function import_stateszoo()
    _run_import_expression("using QuantumSavory; using QuantumSavory.StatesZoo")
end

function import_circuitzoo()
    _run_import_expression("using QuantumSavory; using QuantumSavory.CircuitZoo")
end

# Import timing must happen in a separate Julia process. Keep samples/evals low
# so CI benchmark runs do not spend most of their time measuring process startup.
SUITE["imports"]["using_quantumsavory"] = @benchmarkable import_quantumsavory() evals=1 samples=1
SUITE["imports"]["using_protocolzoo"] = @benchmarkable import_protocolzoo() evals=1 samples=1
SUITE["imports"]["using_stateszoo"] = @benchmarkable import_stateszoo() evals=1 samples=1
SUITE["imports"]["using_circuitzoo"] = @benchmarkable import_circuitzoo() evals=1 samples=1
