SUITE["register"]["backend_microbenchmarks"] = BenchmarkGroup(["backend_microbenchmarks"])

const BENCH_XX = X⊗X

# Small backend-specific register operations. These are intentionally factored
# into named helpers so individual cases can be benchmarked interactively.
function prepare_backend_register(repr; nqubits=2, background=nothing)
    traits = fill(Qubit(), nqubits)
    reprs = fill(repr, nqubits)
    backgrounds = fill(background, nqubits)
    return Register(traits, reprs, backgrounds)
end

function prepare_initialized_backend_register(repr; nqubits=2, background=nothing, time=nothing)
    reg = prepare_backend_register(repr; nqubits=nqubits, background=background)
    for i in 1:nqubits
        if isnothing(time)
            initialize!(reg[i], i == 1 ? X1 : Z1)
        else
            initialize!(reg[i], i == 1 ? X1 : Z1; time=time + i)
        end
    end
    return reg
end

function prepare_entangled_backend_register(repr; background=nothing, time=nothing)
    reg = prepare_initialized_backend_register(repr; nqubits=2, background=background, time=time)
    if isnothing(time)
        apply!(reg[1:2], CNOT)
    else
        apply!(reg[1:2], CNOT; time=time + 3)
    end
    return reg
end

function backend_create_quantumoptics_small()
    prepare_backend_register(QuantumOpticsRepr(); nqubits=2)
end

function backend_create_clifford_small()
    prepare_backend_register(CliffordRepr(); nqubits=2)
end

function backend_create_quantummc_small()
    prepare_backend_register(QuantumMCRepr(); nqubits=2)
end

function backend_create_quantumoptics_large()
    prepare_backend_register(QuantumOpticsRepr(); nqubits=64)
end

function backend_create_clifford_large()
    prepare_backend_register(CliffordRepr(); nqubits=64)
end

function backend_create_with_background()
    prepare_backend_register(QuantumOpticsRepr(); nqubits=2, background=T2Dephasing(1.0))
end

function backend_initialize_slot!(reg)
    initialize!(reg[1], X1)
end

function backend_initialize_slot_with_time!(reg)
    initialize!(reg[1], X1; time=2.0)
end

function backend_apply_cnot!(reg)
    apply!(reg[1:2], CNOT)
end

function backend_apply_cnot_with_time!(reg)
    apply!(reg[1:2], CNOT; time=4.0)
end

function backend_project_traceout!(reg)
    project_traceout!(reg[1], Z)
end

SUITE["register"]["backend_microbenchmarks"]["create"] = BenchmarkGroup(["create"])
SUITE["register"]["backend_microbenchmarks"]["create"]["quantumoptics_small"] = @benchmarkable backend_create_quantumoptics_small()
SUITE["register"]["backend_microbenchmarks"]["create"]["clifford_small"] = @benchmarkable backend_create_clifford_small()
SUITE["register"]["backend_microbenchmarks"]["create"]["quantummc_small"] = @benchmarkable backend_create_quantummc_small()
SUITE["register"]["backend_microbenchmarks"]["create"]["quantumoptics_large"] = @benchmarkable backend_create_quantumoptics_large()
SUITE["register"]["backend_microbenchmarks"]["create"]["clifford_large"] = @benchmarkable backend_create_clifford_large()
SUITE["register"]["backend_microbenchmarks"]["create"]["quantumoptics_t2_background"] = @benchmarkable backend_create_with_background()

SUITE["register"]["backend_microbenchmarks"]["initialize"] = BenchmarkGroup(["initialize"])
SUITE["register"]["backend_microbenchmarks"]["initialize"]["quantumoptics"] = @benchmarkable backend_initialize_slot!(reg) setup=(reg = prepare_backend_register(QuantumOpticsRepr(); nqubits=1)) evals=1
SUITE["register"]["backend_microbenchmarks"]["initialize"]["clifford"] = @benchmarkable backend_initialize_slot!(reg) setup=(reg = prepare_backend_register(CliffordRepr(); nqubits=1)) evals=1
SUITE["register"]["backend_microbenchmarks"]["initialize"]["quantummc"] = @benchmarkable backend_initialize_slot!(reg) setup=(reg = prepare_backend_register(QuantumMCRepr(); nqubits=1)) evals=1
SUITE["register"]["backend_microbenchmarks"]["initialize"]["quantumoptics_t2_time"] = @benchmarkable backend_initialize_slot_with_time!(reg) setup=(reg = prepare_backend_register(QuantumOpticsRepr(); nqubits=1, background=T2Dephasing(1.0))) evals=1

SUITE["register"]["backend_microbenchmarks"]["apply"] = BenchmarkGroup(["apply"])
SUITE["register"]["backend_microbenchmarks"]["apply"]["quantumoptics_cnot"] = @benchmarkable backend_apply_cnot!(reg) setup=(reg = prepare_initialized_backend_register(QuantumOpticsRepr())) evals=1
SUITE["register"]["backend_microbenchmarks"]["apply"]["clifford_cnot"] = @benchmarkable backend_apply_cnot!(reg) setup=(reg = prepare_initialized_backend_register(CliffordRepr())) evals=1
SUITE["register"]["backend_microbenchmarks"]["apply"]["quantummc_cnot"] = @benchmarkable backend_apply_cnot!(reg) setup=(reg = prepare_initialized_backend_register(QuantumMCRepr())) evals=1
SUITE["register"]["backend_microbenchmarks"]["apply"]["quantumoptics_t2_cnot_time"] = @benchmarkable backend_apply_cnot_with_time!(reg) setup=(reg = prepare_initialized_backend_register(QuantumOpticsRepr(); background=T2Dephasing(1.0), time=0.0)) evals=1

SUITE["register"]["backend_microbenchmarks"]["readout"] = BenchmarkGroup(["readout"])
SUITE["register"]["backend_microbenchmarks"]["readout"]["quantumoptics_observable"] = @benchmarkable observable(reg[1:2], BENCH_XX) setup=(reg = prepare_entangled_backend_register(QuantumOpticsRepr()))
SUITE["register"]["backend_microbenchmarks"]["readout"]["clifford_observable"] = @benchmarkable observable(reg[1:2], BENCH_XX) setup=(reg = prepare_entangled_backend_register(CliffordRepr()))
SUITE["register"]["backend_microbenchmarks"]["readout"]["quantumoptics_project_traceout"] = @benchmarkable backend_project_traceout!(reg) setup=(reg = prepare_entangled_backend_register(QuantumOpticsRepr())) evals=1
SUITE["register"]["backend_microbenchmarks"]["readout"]["clifford_project_traceout"] = @benchmarkable backend_project_traceout!(reg) setup=(reg = prepare_entangled_backend_register(CliffordRepr())) evals=1
