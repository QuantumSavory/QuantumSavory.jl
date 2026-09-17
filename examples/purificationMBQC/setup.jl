using QuantumClifford.ECC: CSS, parity_checks
using QuantumClifford: stab_to_gf2, graphstate, Stabilizer, MixedDestabilizer, single_x, single_z, logicalxview, logicalzview
using ResumableFunctions
using ConcurrentSim
using Graphs
using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo.MBQCEntanglementDistillation
import QuantumClifford
import QuantumOptics

"""Run the full MBQC purification pipeline described in ["Measurement-Based Entanglement Distillation and Constant-Rate Quantum Repeaters over Arbitrary Distances"](https://journals.aps.org/prl/abstract/10.1103/2bp8-cdxc):
1. Construct graph states on Alice's and Bob's sides
2. Convert graph states to resource states via local Clifford corrections
3. Distribute noisy Bell pairs between Alice and Bob
4. Perform Bell measurements and apply Pauli frame corrections

The long-range Alice-Bob links are generated with `long_range_pairstate`;
the pipeline expects them to be`XX ZZ`, so if `long_range_pairstate` has different stabilizers provide the `long_range_correction` gates
(applied to Alice's communication qubit after heralding) that rotate it to `XX ZZ`.
The local links used to build the graph states are generated with `local_pairstate`;
if `local_pairstate` is not in graph form (stabilizers `XZ ZX`), provide the `local_correction` gates that rotate it there (see `GraphStateConstructor`).
"""
@resumable function run_purification(sim, net, n, resource_state, alice_nodes, bob_nodes,
                                     communication_slot, storage_slot,
                                     H1, H2, logxs, logzs; rounds=1,
                                     long_range_pairstate=StabilizerState("ZZ XX"),
                                     long_range_correction=nothing,
                                     local_pairstate=StabilizerState("ZX XZ"),
                                     local_correction=nothing)
    @assert n <= 63 "n=$n exceeds maximum of 63 bits for Int64 encoding"
    alice_chief_idx = alice_nodes[1]
    bob_chief_idx = bob_nodes[1]

    g, hadamard_idx, iphase_idx, flips_idx = graphstate(resource_state)

    graphA = GraphStateConstructor(sim, net, g, alice_nodes, communication_slot, storage_slot;
        pairstate=local_pairstate, correction=local_correction)
    graphB = GraphStateConstructor(sim, net, g, bob_nodes, communication_slot, storage_slot;
        pairstate=local_pairstate, correction=local_correction)
    resourceA = GraphToResource(sim, net, alice_nodes, storage_slot, hadamard_idx, iphase_idx, flips_idx)
    resourceB = GraphToResource(sim, net, bob_nodes, storage_slot, hadamard_idx, iphase_idx, flips_idx)
    alice_bell_meas = PurifierBellMeasurements(sim, net, collect(alice_nodes[1:n]),
        alice_chief_idx, bob_chief_idx, communication_slot, storage_slot)
    bob_bell_meas = PurifierBellMeasurements(sim, net, collect(bob_nodes[1:n]),
        bob_chief_idx, alice_chief_idx, communication_slot, storage_slot)
    alice_tracker = MBQCPurificationTracker(sim, net, alice_nodes, n,
        alice_chief_idx, bob_chief_idx, H1, H2, logxs, logzs,
        communication_slot, storage_slot, false)
    bob_tracker = MBQCPurificationTracker(sim, net, bob_nodes, n,
        bob_chief_idx, alice_chief_idx, H1, H2, logxs, logzs,
        communication_slot, storage_slot, true)
    @process alice_tracker()
    @process bob_tracker()

    round = 0
    while rounds == -1 || round < rounds
        round += 1

        # Step 1: Construct graph states
        g1 = @process graphA()
        g2 = @process graphB()
        @yield g1 & g2

        # Step 2 & 3: Convert to resource states and distribute Bell pairs
        r1 = @process resourceA()
        r2 = @process resourceB()
        entanglers = []
        for i in 1:n
            entangler = EntanglerProt(sim, net, alice_nodes[i], bob_nodes[i];
                pairstate=long_range_pairstate,
                chooseslotA=communication_slot, chooseslotB=communication_slot,
                attempts=-1, rounds=1)
            e = @process entangler()
            push!(entanglers, e)
        end
        @yield reduce(&, (entanglers..., r1, r2))

        # apply the long-range correction gates that bring the heralded pairs to stabilizers `XX ZZ`
        if !isnothing(long_range_correction)
            for i in 1:n
                for gate in long_range_correction
                    apply!(net[alice_nodes[i]][communication_slot], gate)
                end
            end
        end

        # Step 4: Bell measurements
        m1 = @process alice_bell_meas()
        m2 = @process bob_bell_meas()
        @yield m1 & m2
    end
end

##
# Set up the [4,2,2] CSS code.
# The protocol takes an [n,k,d] CSS code and uses n noisy Bell pairs
# to distill k higher-fidelity Bell pairs. In this example, we use n=4, k=2, d=2.
# The parity check matrices H1 (X-type) and H2 (Z-type) define the syndrome measurements,
# and logxs/logzs are the logical X and Z operators used to verify the purified pairs.
##

h1 = [1 1 1 1]
h2 = [1 1 1 1]
code = parity_checks(CSS(h1, h2)) # S"XXXX ZZZZ"
c, n = size(code)
k = n - c # k=2 logical qubits from n=4 physical qubits

code_binary = stab_to_gf2(code)
H1 = code_binary[:, 1:n]
H2 = code_binary[:, n+1:end]
code_md = MixedDestabilizer(code)
logxs = logicalxview(code_md)
logzs = logicalzview(code_md)

# Build the resource state (equation 1 from the paper)
resource_state = vcat(
    hcat(code, zero(Stabilizer, c, k)),
    Stabilizer([l⊗single_x(k, i) for (i, l) in enumerate(logxs)]),
    Stabilizer([l⊗single_z(k, i) for (i, l) in enumerate(logzs)]),
)

##
# Common simulation layout.
# Each node has 2 slots: slot 1 (communication) for Bell pair generation via EntanglerProt,
# and slot 2 (storage) for holding the graph state qubit.
# Alice occupies nodes 1..n+k and Bob occupies nodes n+k+1..2*(n+k).
##

perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
communication_slot = 1
storage_slot = 2
alice_nodes = collect(1:n+k)
bob_nodes = collect(n+k+1:2*(n+k))
