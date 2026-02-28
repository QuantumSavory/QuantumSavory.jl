@testitem "Noninstant and Backgrounds - Qubit" begin
using Test
using QuantumSavory: NonInstantGate
using QuantumSavory
using LinearAlgebra

##
# Time of application and gate durations
reg = Register([Qubit(),Qubit()])
initialize!(reg[1])
initialize!(reg[2])
uptotime!(reg[1],0.2)
uptotime!(reg[1],0.2)
@test_throws ErrorException uptotime!(reg[1],0.1)
apply!(reg[1], H; time=0.3)
apply!(reg[1], NonInstantGate(H,0.1); time=0.4)
apply!([reg[1],reg[2]], NonInstantGate(CNOT, 0.1))
@test_throws ErrorException uptotime!(reg[1],0.55)
@test_throws ErrorException apply!(reg[1], H; time=0.55)

##
# Kraus vs Lindblad comparison (should give the same results)
function kraus_lindblad_test(background,initstate)
    reg = Register([Qubit(),Qubit()],[background, background])
    initialize!(reg[1], initstate)
    initialize!(reg[2], initstate)
    uptotime!(reg[1],0.2)
    uptotime!(reg[2],0.1)
    uptotime!(reg[2],0.2)
    # Test that Kraus weights are calculated correctly
    @test reg.staterefs[1].state[] ≈ reg.staterefs[2].state[]

    regb = Register([Qubit(),Qubit()],[background, background])
    initialize!(regb[1], initstate)
    initialize!(regb[2], initstate)
    subsystemcompose(regb[1],regb[2])
    uptotime!(regb[1],0.2)
    uptotime!(regb[2],0.1)
    uptotime!(regb[2],0.2)
    @test reg.staterefs[1].state[]⊗reg.staterefs[2].state[] ≈ regb.staterefs[2].state[] # compare composed vs not-composed evolution

    apply!(reg[1],ConstantHamiltonianEvolution(IdentityOp(X1),0.1),time=0.3) # Lindblad evolution
    uptotime!(reg[2],0.4)                                                    # Kraus evolution
    @test reg.staterefs[1].state[] ≈ reg.staterefs[2].state[] # compare Kraus evolution vs Lindblad evolution

    apply!(regb[1],ConstantHamiltonianEvolution(IdentityOp(X1),0.1),time=0.3)
    uptotime!(regb[2],0.4)
    @test reg.staterefs[1].state[]⊗reg.staterefs[2].state[] ≈ regb.staterefs[2].state[]
end

kraus_lindblad_test(T1Decay(1.0),Z1)
kraus_lindblad_test(T1Decay(1.0),Z2)
kraus_lindblad_test(T1Decay(1.0),X1)
kraus_lindblad_test(T1Decay(1.0),X2)
kraus_lindblad_test(T2Dephasing(1.0),Z1)
kraus_lindblad_test(T2Dephasing(1.0),Z2)
kraus_lindblad_test(T2Dephasing(1.0),X1)
kraus_lindblad_test(T2Dephasing(1.0),X2)
kraus_lindblad_test(T1T2Noise(1.0,1.0),Z1)
kraus_lindblad_test(T1T2Noise(1.0,1.0),Z2)
kraus_lindblad_test(T1T2Noise(1.0,1.0),X1)
kraus_lindblad_test(T1T2Noise(1.0,1.0),X2)
kraus_lindblad_test(T1T2Noise(1.0,3.0),Z1)
kraus_lindblad_test(T1T2Noise(1.0,3.0),Z2)
kraus_lindblad_test(T1T2Noise(1.0,3.0),X1)
kraus_lindblad_test(T1T2Noise(1.0,3.0),X2)

##
# Kraus composition check (the effect of two short Kraus operators should be the same as the effect of one long Kraus operator)

function kraus_composition_test(background,initstate, obs)
    reg = Register([Qubit(),Qubit()],[background, background])
    initialize!(reg[1], initstate)
    initialize!(reg[2], initstate)
    uptotime!(reg[1],0.1)
    uptotime!(reg[1],0.2)
    uptotime!(reg[1],0.3)
    uptotime!(reg[1],0.4)
    uptotime!(reg[1],0.5)
    uptotime!(reg[2],0.5)
    o1 = observable(reg[1], obs)
    o2 = observable(reg[2], obs)
    #println("$o1 $o2")
    return o1 ≈ o2
end

for state in (X1, X2, Z1, Z2, Y1, Y2)
    for obs in (X, Z, Y)
        @test kraus_composition_test(T1Decay(1.0),state,obs)
        @test kraus_composition_test(T2Dephasing(1.0),state,obs)
        @test kraus_composition_test(Depolarization(1.0),state,obs)
        @test kraus_composition_test(T1T2Noise(1.0,1.0),state,obs)
        @test kraus_composition_test(T1T2Noise(1.0,3.0),state,obs)
    end
end

##
# Kraus op normalization check

function kraus_normed(kraus_ops)
    # check we have properly normed kraus_ops
    kraus_sum = sum((k'*k for k in kraus_ops))
    return kraus_sum.data ≈ LinearAlgebra.I(size(kraus_ops[1],1))
end

for δ in [0.1,1.0,2.0,10.]
    @test kraus_normed(krausops(T1Decay(1.0),δ))
    @test kraus_normed(krausops(T2Dephasing(1.0),δ))
    @test kraus_normed(krausops(Depolarization(1.0),δ))
    @test kraus_normed(krausops(T1T2Noise(1.0,1.0),δ))
    @test kraus_normed(krausops(T1T2Noise(1.0,3.0),δ))
end

##
# Kraus equivalences and consistency checks for T2 noise

function krausT2a(t) # manually reimplement one of the T2 representations
    l = 1-exp(-2t)
    [1 0; 0 sqrt(1-l)], [0 0; 0 sqrt(l)]
end

function krausT2b(t) # manually reimplement another of the T2 representations
    p = 1-exp(-t)
    i = sqrt(1-p/2)
    z = sqrt(p/2)
    [i 0; 0 i], [z 0; 0 -z]
end

function kraus_unitary_equivalence(kraus_ops_a, kraus_ops_b)
    # get the linear operations that relates one set of kraus operators to another set of kraus operators
    u = (hcat(vec.(kraus_ops_a)...)' / hcat(vec.(kraus_ops_b)...)')
    # check that it is unitary
    return abs(det(u)) ≈ 1
end

for δ in [0.1,1.0,2.0,10.]
    t2 = [op.data for op in krausops(T2Dephasing(1.0), δ)]
    t2a = krausT2a(δ)
    t2b = krausT2b(δ)
    @test kraus_unitary_equivalence(t2, t2a)
    @test kraus_unitary_equivalence(t2, t2b)
    @test kraus_unitary_equivalence(t2a, t2b)
end

##
# Test that T1T2Noise reduces to T1 alone when T2 > 2*T1

function test_t1t2_reduces_to_t1(t1, t2, δ)
    # When T2 = 2*T1, there's no pure dephasing, only amplitude damping
    noise_t1t2 = T1T2Noise(t1=t1, t2=t2)
    noise_t1 = T1Decay(t1=t1)

    reg1 = Register([Qubit()], [noise_t1t2])
    reg2 = Register([Qubit()], [noise_t1])

    initialize!(reg1[1], X1)
    initialize!(reg2[1], X1)

    uptotime!(reg1[1], δ)
    uptotime!(reg2[1], δ)

    return reg1.staterefs[1].state[] ≈ reg2.staterefs[1].state[]
end

for (t1, t2) in [(0.5, 1.0), (1.0, 2.0), (1.0, 2.5), (1.5, 4.0)]
    for δ in [0.1,1.0,2.0,10.]
        @test test_t1t2_reduces_to_t1(t1, t2, δ)
    end
end

##
# Test alternative Kraus operator versions


function test_kraus_alt(noise, δ)
    reg1 = Register([Qubit()], [noise])
    reg2 = Register([Qubit()], [QuantumSavory.KrausAltWrapper(noise)])

    initialize!(reg1[1], X1)
    initialize!(reg2[1], X1)

    uptotime!(reg1[1], δ)
    uptotime!(reg2[1], δ)

    return reg1.staterefs[1].state[] ≈ reg2.staterefs[1].state[]
end

for (t1, t2) in [(1.5, 1.0), (3.0, 2.0), (1.0, 1.5)]
    for δ in [0.1,1.0,2.0,10.]
        @test test_kraus_alt(T1T2Noise(t1, t2), δ)
    end
end


end
