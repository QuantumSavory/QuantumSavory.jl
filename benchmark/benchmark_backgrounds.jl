SUITE["backgrounds"] = BenchmarkGroup(["backgrounds"])
SUITE["backgrounds"]["uptotime"] = BenchmarkGroup(["uptotime"])
SUITE["backgrounds"]["krausops"] = BenchmarkGroup(["krausops"])
SUITE["backgrounds"]["lindblad"] = BenchmarkGroup(["lindblad"])

function prepare_background_register(background, initstate)
    reg = Register([Qubit(), Qubit()], [background, background])
    initialize!(reg[1], initstate)
    initialize!(reg[2], initstate)
    return reg
end

function prepare_lindblad_background_register(background, initstate)
    reg = prepare_background_register(background, initstate)
    uptotime!(reg[1], 0.3)
    return reg
end

# Time evolution and Kraus generation cover the noise models exercised by the test suite.
SUITE["backgrounds"]["uptotime"]["t1_x"] = @benchmarkable uptotime!(reg[1], 0.5) setup=(reg = prepare_background_register(T1Decay(1.0), X1)) evals=1
SUITE["backgrounds"]["uptotime"]["t2_x"] = @benchmarkable uptotime!(reg[1], 0.5) setup=(reg = prepare_background_register(T2Dephasing(1.0), X1)) evals=1
SUITE["backgrounds"]["uptotime"]["depolarization_x"] = @benchmarkable uptotime!(reg[1], 0.5) setup=(reg = prepare_background_register(Depolarization(1.0), X1)) evals=1
SUITE["backgrounds"]["uptotime"]["t1t2_x"] = @benchmarkable uptotime!(reg[1], 0.5) setup=(reg = prepare_background_register(T1T2Noise(1.0, 3.0), X1)) evals=1

SUITE["backgrounds"]["krausops"]["t1"] = @benchmarkable krausops(T1Decay(1.0), 0.5)
SUITE["backgrounds"]["krausops"]["t2"] = @benchmarkable krausops(T2Dephasing(1.0), 0.5)
SUITE["backgrounds"]["krausops"]["depolarization"] = @benchmarkable krausops(Depolarization(1.0), 0.5)
SUITE["backgrounds"]["krausops"]["t1t2"] = @benchmarkable krausops(T1T2Noise(1.0, 3.0), 0.5)

SUITE["backgrounds"]["lindblad"]["t1"] = @benchmarkable apply!(reg[1], ConstantHamiltonianEvolution(IdentityOp(X1), 0.1); time=0.3) setup=(reg = prepare_lindblad_background_register(T1Decay(1.0), X1)) evals=1
SUITE["backgrounds"]["lindblad"]["t2"] = @benchmarkable apply!(reg[1], ConstantHamiltonianEvolution(IdentityOp(X1), 0.1); time=0.3) setup=(reg = prepare_lindblad_background_register(T2Dephasing(1.0), X1)) evals=1
SUITE["backgrounds"]["lindblad"]["t1t2"] = @benchmarkable apply!(reg[1], ConstantHamiltonianEvolution(IdentityOp(X1), 0.1); time=0.3) setup=(reg = prepare_lindblad_background_register(T1T2Noise(1.0, 3.0), X1)) evals=1
