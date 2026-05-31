SUITE["backendops"] = BenchmarkGroup(["backendops"])

function backend_register(representation; background = nothing)
    traits = [Qubit(), Qubit()]
    reprs = [representation(), representation()]
    backgrounds = isnothing(background) ? nothing : [background, background]
    reg = isnothing(backgrounds) ? Register(traits, reprs) : Register(traits, reprs, backgrounds)
    initialize!(reg[1], X1; time = 0.0)
    initialize!(reg[2], Z1; time = 0.0)
    return reg
end

SUITE["backendops"]["initialize"] = BenchmarkGroup(["initialize"])
SUITE["backendops"]["initialize"]["quantumoptics"] =
    @benchmarkable initialize!(_reg[1], X1) setup = (_reg = Register([Qubit()], [QuantumOpticsRepr()])) evals = 1
SUITE["backendops"]["initialize"]["clifford"] =
    @benchmarkable initialize!(_reg[1], X1) setup = (_reg = Register([Qubit()], [CliffordRepr()])) evals = 1
SUITE["backendops"]["initialize"]["quantummc"] =
    @benchmarkable initialize!(_reg[1], X1) setup = (_reg = Register([Qubit()], [QuantumMCRepr()])) evals = 1

SUITE["backendops"]["apply"] = BenchmarkGroup(["apply"])
SUITE["backendops"]["apply"]["single_qubit_quantumoptics"] =
    @benchmarkable apply!(_reg[1], H) setup = (_reg = backend_register(QuantumOpticsRepr)) evals = 1
SUITE["backendops"]["apply"]["single_qubit_clifford"] =
    @benchmarkable apply!(_reg[1], H) setup = (_reg = backend_register(CliffordRepr)) evals = 1
SUITE["backendops"]["apply"]["two_qubit_quantumoptics"] =
    @benchmarkable apply!([_reg[1], _reg[2]], CNOT) setup = (_reg = backend_register(QuantumOpticsRepr)) evals = 1
SUITE["backendops"]["apply"]["two_qubit_clifford"] =
    @benchmarkable apply!([_reg[1], _reg[2]], CNOT) setup = (_reg = backend_register(CliffordRepr)) evals = 1

SUITE["backendops"]["backgrounds"] = BenchmarkGroup(["backgrounds"])
SUITE["backendops"]["backgrounds"]["uptotime_t2_quantumoptics"] =
    @benchmarkable uptotime!(_reg[1], 1.0) setup = (_reg = backend_register(QuantumOpticsRepr; background = T2Dephasing(10.0))) evals = 1
SUITE["backendops"]["backgrounds"]["uptotime_t2_clifford"] =
    @benchmarkable uptotime!(_reg[1], 1.0) setup = (_reg = backend_register(CliffordRepr; background = T2Dephasing(10.0))) evals = 1
