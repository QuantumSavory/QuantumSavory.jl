@testitem "Noninstant and Backgrounds - Clifford" begin
using Test
using QuantumSavory
using Statistics: mean

##
# state vector vs clifford comparison of background noise processes

function run_evolution(reg, init, gate, obs)
    if isa(init, Tuple)
        i1, i2 = init
        initialize!(reg[1], i1)
        initialize!(reg[2], i2)
    else
        initialize!((reg[1],reg[2]), init)
    end
    uptotime!(reg[2],0.1)
    uptotime!(reg[2],0.2)
    apply!((reg[1],reg[2]), gate)
    uptotime!(reg[1],0.4)
    uptotime!(reg[2],0.3)
    uptotime!(reg[2],0.4)
    obs = observable((reg[1],reg[2]), obs)
    return obs
end

function vector_vs_clifford_test(background, init, gate, obs)
    reg_qo() = Register([Qubit(),Qubit()],[background, background])
    reg_qc() = Register([Qubit(),Qubit()],[CliffordRepr(),CliffordRepr()],[background, background])
    obs_qo = run_evolution(reg_qo(), init, gate, obs)
    samples = 1000
    obs_qc = mean([run_evolution(reg_qc(), init, gate, obs) for _ in 1:samples])
    #println("$(real(obs_qo)), $(real(obs_qc))")
    return abs(obs_qo - obs_qc) < 4/sqrt(samples)
end

for l in (X1, X2, Z1, Z2, Y1, Y2)
    for r in (X1, X2, Z1, Z2, Y1, Y2)
        for obs in (X⊗X, Z⊗Z, X⊗Y)
            for gate in (CNOT, CPHASE)
                for init in ((l,r), (l⊗r)) # to check if subsystemcompose works properly
                    @test vector_vs_clifford_test(T2Dephasing(1.0), init, gate, obs)
                    @test vector_vs_clifford_test(Depolarization(1.0), init, gate, obs)
                end
            end
        end
    end
end

end
