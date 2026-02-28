using QuantumClifford.ECC: CSS, parity_checks
using QuantumClifford: stab_to_gf2, graphstate, Stabilizer, MixedDestabilizer, single_x, single_z, logicalxview, logicalzview
using ResumableFunctions
using ConcurrentSim
using Graphs
using QuantumSavory
using QuantumSavory.ProtocolZoo
import QuantumClifford
import QuantumOpticsBase

"""Run the full MBQC purification pipeline:
1. Construct graph states on Alice's and Bob's sides
2. Convert graph states to resource states via local Clifford corrections
3. Distribute noisy Bell pairs between Alice and Bob
4. Perform Bell measurements and apply pauli
"""
@resumable function run_purification(sim, net, n, resource_state, alice_nodes, bob_nodes,
                                     communication_slot, storage_slot, pairstate,
                                     H1, H2, logxs, logzs; rounds=1)
    @assert n <= 63 "n=$n exceeds maximum of 63 bits for Int64 encoding"
    alice_chief_idx = alice_nodes[1]
    bob_chief_idx = bob_nodes[1]

    g, hadamard_idx, iphase_idx, flips_idx = graphstate(resource_state)

    graphA = GraphStateConstructor(sim, net, g, alice_nodes, communication_slot, storage_slot)
    graphB = GraphStateConstructor(sim, net, g, bob_nodes, communication_slot, storage_slot)
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

        # Step 2&3: Convert to resource states and distribute Bell pairs
        r1 = @process resourceA()
        r2 = @process resourceB()
        entanglers = []
        for i in 1:n
            entangler = EntanglerProt(sim, net, alice_nodes[i], bob_nodes[i];
                pairstate=pairstate,
                chooseA=communication_slot, chooseB=communication_slot,
                success_prob=1.0, attempts=-1, rounds=1)
            e = @process entangler()
            push!(entanglers, e)
        end
        @yield reduce(&, (entanglers..., r1, r2))

        # Step 4: Bell measurements
        m1 = @process alice_bell_meas()
        m2 = @process bob_bell_meas()
        @yield m1 & m2
    end
end

##
# Set up the [4,2,2] CSS code
##

"""Create a noisy Werner state with fidelity F."""
function noisy_pair_func(perfect_pair, F)
    p = (4*F - 1) / 3
    perfect_pair_dm = SProjector(perfect_pair)
    mixed_dm = MixedState(perfect_pair_dm)
    return p * perfect_pair_dm + (1 - p) * mixed_dm
end

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
# Configure and run the simulation
##

perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
communication_slot = 1
storage_slot = 2
alice_nodes = collect(1:n+k)
bob_nodes = collect(n+k+1:2*(n+k))

# Perfect Bell Pairs


@info "Input fidelity: 1 (Perfect pair)"
fidelity = 1
pairstate = noisy_pair_func(perfect_pair, fidelity)
for i in 1:5
    println(i)
    registers = [Register(2) for _ in 1:2*(n+k)]
    net = RegisterNet(registers)
    sim = get_time_tracker(net)

    @process run_purification(sim, net, n, resource_state, alice_nodes, bob_nodes,
        communication_slot, storage_slot, pairstate, H1, H2, logxs, logzs, rounds=1)

    run(sim, 50.0)
    alice_tag = query(net[alice_nodes[n+i]][storage_slot], PurifiedEntanglementCounterpart, ❓, ❓)
    bob_tag = query(net[bob_nodes[n+i]][storage_slot], PurifiedEntanglementCounterpart, ❓, ❓)
    # check whether purification was successful
    #@assert !isnothing(alice_tag)
    #@assert !isnothing(bob_tag)
    f = observable([net[alice_nodes[n+i]], net[bob_nodes[n+i]]], [storage_slot, storage_slot], projector(perfect_pair))
    @info "Purified pair $i: fidelity=$(round(f, digits=4)), alice_tag=$(alice_tag), bob_tag=$(bob_tag)"
    @assert isapprox(f, 1.0) # Purified pair should be perfect
end
##
# Verify acceptance rate matches theory: P_accept = (1 + 3p^4) / 4
# For [[4,2,2]] with Werner input pairs of fidelity F, both syndrome parities
# pass with probability (1+3p^4)/4 where p = (4F-1)/3 is the Bloch shrink factor.
##

N_trials = 100
for test_fidelity in [0.7, 0.75, 0.8, 0.85, 0.9]
    p_bloch = (4*test_fidelity - 1) / 3
    P_accept_theory = (1 + 3*p_bloch^4) / 4

    n_success = 0
    for _ in 1:N_trials
        pairstate_noisy = noisy_pair_func(perfect_pair, test_fidelity)
        regs_trial = [Register(2) for _ in 1:2*(n+k)]
        net_trial = RegisterNet(regs_trial)
        sim_trial = get_time_tracker(net_trial)
        @process run_purification(sim_trial, net_trial, n, resource_state, alice_nodes, bob_nodes,
            communication_slot, storage_slot, pairstate_noisy, H1, H2, logxs, logzs, rounds=1)
        run(sim_trial, 5.0)
        tag = query(net_trial[alice_nodes[n+1]][storage_slot], PurifiedEntanglementCounterpart, ❓, ❓)
        n_success += !isnothing(tag)
    end

    P_accept_empirical = n_success / N_trials
    σ = sqrt(P_accept_theory * (1 - P_accept_theory) / N_trials)
    @info "Acceptance rate (F=$(test_fidelity)): theory=$(round(P_accept_theory, digits=4)), empirical=$(round(P_accept_empirical, digits=4)) ± $(round(4σ, digits=4)) (4σ, N=$(N_trials))"
    @assert abs(P_accept_empirical - P_accept_theory) < 4σ "Acceptance rate mismatch at F=$(test_fidelity): theory=$(round(P_accept_theory,digits=4)), empirical=$(round(P_accept_empirical,digits=4)), 4σ=$(round(4σ,digits=4))"
end