SUITE["coreops"] = BenchmarkGroup(["coreops"])

const _coreops_representations = (
    ("quantumoptics", QuantumOpticsRepr()),
    ("clifford", CliffordRepr()),
    ("quantummc", QuantumMCRepr()),
)

const _coreops_observable_representations = (
    ("quantumoptics", QuantumOpticsRepr()),
    ("clifford", CliffordRepr()),
)

const _coreops_bell = StabilizerState("XX ZZ")
const _coreops_bell_projector = SProjector(_coreops_bell)

function _coreops_single_qubit_register(repr)
    reg = Register(1, repr)
    initialize!(reg[1], X1)
    return reg
end

function _coreops_two_qubit_register(repr)
    reg = Register(2, repr)
    initialize!(reg[1], X1)
    initialize!(reg[2], Z1)
    return reg
end

function _coreops_dephasing_register(repr)
    reg = Register([Qubit()], [repr], [T2Dephasing(10.0)])
    initialize!(reg[1], X1, time=0.0)
    return reg
end

SUITE["coreops"]["construction"] = BenchmarkGroup(["construction"])
for (label, repr) in _coreops_representations
    SUITE["coreops"]["construction"]["$(label)_register_8_slots"] =
        @benchmarkable Register(8, $repr)
end

SUITE["coreops"]["initialization"] = BenchmarkGroup(["initialization"])
for (label, repr) in _coreops_representations
    SUITE["coreops"]["initialization"]["$(label)_initialize_x"] =
        @benchmarkable initialize!(_reg[1], X1) setup=(_reg = Register(1, $repr)) evals=1
end

SUITE["coreops"]["gates"] = BenchmarkGroup(["gates"])
for (label, repr) in _coreops_representations
    SUITE["coreops"]["gates"]["$(label)_apply_x"] =
        @benchmarkable apply!(_reg[1], X) setup=(_reg = _coreops_single_qubit_register($repr)) evals=1
    SUITE["coreops"]["gates"]["$(label)_apply_cnot"] =
        @benchmarkable apply!((_reg[1], _reg[2]), CNOT) setup=(_reg = _coreops_two_qubit_register($repr)) evals=1
end

SUITE["coreops"]["observable"] = BenchmarkGroup(["observable"])
for (label, repr) in _coreops_observable_representations
    SUITE["coreops"]["observable"]["$(label)_single_x"] =
        @benchmarkable observable(_reg[1], X) setup=(_reg = _coreops_single_qubit_register($repr)) evals=1
    SUITE["coreops"]["observable"]["$(label)_pair_projector"] =
        @benchmarkable observable(_reg[1:2], _coreops_bell_projector) setup=(_reg = Register(2, $repr); initialize!(_reg[1:2], _coreops_bell)) evals=1
end

SUITE["coreops"]["measurement"] = BenchmarkGroup(["measurement"])
for (label, repr) in _coreops_observable_representations
    SUITE["coreops"]["measurement"]["$(label)_project_x"] =
        @benchmarkable project_traceout!(_reg[1], X) setup=(_reg = _coreops_single_qubit_register($repr)) evals=1
end

SUITE["coreops"]["traceout"] = BenchmarkGroup(["traceout"])
for (label, repr) in _coreops_representations
    SUITE["coreops"]["traceout"]["$(label)_single_slot"] =
        @benchmarkable traceout!(_reg[1]) setup=(_reg = _coreops_single_qubit_register($repr)) evals=1
end

SUITE["coreops"]["backgrounds"] = BenchmarkGroup(["backgrounds"])
for (label, repr) in _coreops_observable_representations
    SUITE["coreops"]["backgrounds"]["$(label)_uptotime_t2"] =
        @benchmarkable uptotime!(_reg[1], 5.0) setup=(_reg = _coreops_dephasing_register($repr)) evals=1
end
