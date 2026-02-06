
struct QCGateSequence <: QuantumClifford.AbstractSymbolicOperator
    gates # TODO constructor that flattens nested QCGateSequence
end
function QuantumClifford.apply!(state::QuantumClifford.MixedDestabilizer, gseq::QCGateSequence, indices::AbstractVector{Int})
    for g in gseq.gates[end:-1:begin]
        apply_popindex!(state, g, indices)
    end
    state
end
apply_popindex!(state, g::QuantumClifford.AbstractSingleQubitOperator, indices::AbstractVector{Int}) = QuantumClifford.apply!(state, g(pop!(indices)))
apply_popindex!(state, g::QuantumClifford.AbstractTwoQubitOperator, indices::AbstractVector{Int}) = QuantumClifford.apply!(state, g(pop!(indices),pop!(indices)))



"""
Compute the squared overlap |⟨state1|state2⟩|² between two MixedDestabilizer states.

The algorithm works by finding the intersection of the stabilizer groups of the two states:
1. For each stabilizer generator of state1, check if it has an anticommuting partner
   in the destabilizers of state2. If it does, that stabilizer IS in the intersection
   (because it corresponds to a stabilizer in state2's group).
2. Keep only the stabilizers from state1 that have such an anticommuting partner
   (i.e., those that are in the intersection of both stabilizer groups).
3. For each stabilizer in the intersection, verify that it has the same phase in both states
   using the project! function. If any phases differ, the overlap is zero.
4. If all phases match, the squared overlap is 2^(size of intersection) / 2^(number of qubits).

Returns a real number in [0, 1]: the squared magnitude of the inner product.
For pure stabilizer states, this equals the fidelity between the states.
"""
function inner_product_mixed_destab(state1, state2)
    n = QuantumClifford.nqubits(state1)
    @assert n == QuantumClifford.nqubits(state2) "States must have the same number of qubits"

    stab1 = QuantumClifford.stabilizerview(state1)
    destab2 = QuantumClifford.destabilizerview(state2)

    # Find the intersection of stabilizer groups:
    # A stabilizer from state1 is in the intersection if and only if
    # it has an anticommuting partner in destabilizerview(state2).
    # This is because the destabilizers form a dual basis to the stabilizers:
    # each stabilizer S_i anticommutes with exactly its paired destabilizer D_i.
    # If a stabilizer from state1 has such a partner in state2's destabilizers,
    # it means that stabilizer is also in state2's stabilizer group.
    intersection_indices = Int[]
    destab2_tab = QuantumClifford.tab(destab2)
    for i in 1:length(stab1)
        pauli_i = stab1[i]
        has_anticommuting_partner = false
        for j in 1:length(destab2)
            if QuantumClifford.comm(pauli_i, destab2_tab, j) != 0x0
                has_anticommuting_partner = true
                break
            end
        end
        if has_anticommuting_partner
            push!(intersection_indices, i)
        end
    end

    # If intersection is empty, we need to check if the states have any overlap
    # For maximally mixed states or states with no common stabilizers,
    # the overlap is 2^0 / 2^n = 1/2^n if phases match (trivially true for empty intersection)
    intersection_size = length(intersection_indices)

    # For each stabilizer in the intersection, check that the phase matches in state2
    for idx in intersection_indices
        pauli = stab1[idx]
        # Project a copy of state2 onto this stabilizer to get its phase
        state2_copy = copy(state2)
        _, anticom_idx, result = QuantumClifford.project!(state2_copy, pauli)

        # If anticom_idx != 0, the stabilizer anticommutes with something in state2,
        # which shouldn't happen for stabilizers in the intersection
        if anticom_idx != 0
            # This means pauli is not in the stabilizer group of state2
            # (it anticommutes with some logical or the state changed)
            return 0.0
        end

        # result contains the phase: 0x00 for +1, 0x02 for -1
        # The stabilizer in state1 has the phase encoded in pauli.phase[]
        # We need to check if they match
        if result != pauli.phase[]
            return 0.0
        end
    end

    # All phases match, compute the inner product
    # ⟨state1|state2⟩ = 2^intersection_size / 2^n = 2^(intersection_size - n)
    return exp2(intersection_size - n)
end

#=
A bunch of tests to be upstreamed

# Test 6: Pure state vs maximally mixed (single qubit)
println("Test 6: |0> vs maximally mixed single qubit")
state_pure = MixedDestabilizer(S"+Z")
state_mixed = one(MixedDestabilizer, 0, 1)  # rank=0, 1 qubit
println("Pure state: $state_pure")
println("Mixed state: $state_mixed")
result6 = inner_product_mixed_destab(state_pure, state_mixed)
println("Result: $result6 (expected: 1/sqrt(2) = 0.707...)")
# A maximally mixed state ρ = I/2, and <ψ|ρ|ψ> = 1/2 for any |ψ>
# But this is <ψ|φ>, not trace. Need to reconsider...

# Test 7: Partial overlap
println("\nTest 7: States with partial stabilizer overlap")
# |00> is stabilized by +ZI, +IZ
# A mixed state stabilized only by +ZZ has rank 1
state_00 = MixedDestabilizer(S"+ZI +IZ")
state_partial = one(MixedDestabilizer, 1, 2)
println("state_00: ")
println(state_00)
println("state_partial (rank 1 on 2 qubits, just +ZI):")
# Need to construct a proper rank-1 state
state_rank1 = MixedDestabilizer(Destabilizer(S"+XI +IZ"), 1)
println(state_rank1)

# Actually let me test differently - test two states that share some but not all stabilizers
println("\nTest 8: |+0> vs |00>")
# |+0> is stabilized by +XI, +IZ
# |00> is stabilized by +ZI, +IZ
# They share +IZ, so intersection has size 1
# Inner product should be <+0|00> = (1/√2)(<0| + <1|)|00> = 1/√2 = 0.707...
state_plus0 = MixedDestabilizer(S"+XI +IZ")
state_00_2 = MixedDestabilizer(S"+ZI +IZ")
result8 = inner_product_mixed_destab(state_plus0, state_00_2)
println("Result: $result8 (expected: 1/√2 = $(1/sqrt(2)))")

println("\nTest 9: |+0> vs |10>")
# |+0> is stabilized by +XI, +IZ
# |10> is stabilized by -ZI, +IZ
# They share +IZ, so intersection has size 1
# Phase check: +IZ has same phase in both (0x00)
# Inner product should be <+0|10> = (1/√2)(<0| + <1|)|10> = 1/√2
state_plus0_2 = MixedDestabilizer(S"+XI +IZ")
state_10 = MixedDestabilizer(S"-ZI +IZ")
result9 = inner_product_mixed_destab(state_plus0_2, state_10)
println("Result: $result9 (expected: 1/√2 = $(1/sqrt(2)))")

println("\nTest 10: |++> vs |00>")
# |++> is stabilized by +XI, +IX
# |00> is stabilized by +ZI, +IZ
# Intersection should be empty (no common stabilizers)
state_plusplus = MixedDestabilizer(S"+XI +IX")
state_00_3 = MixedDestabilizer(S"+ZI +IZ")
result10 = inner_product_mixed_destab(state_plusplus, state_00_3)
println("Result: $result10 (expected: 1/2 = 0.5)")
# <++|00> = <+|0> * <+|0> = (1/√2) * (1/√2) = 1/2

=#
