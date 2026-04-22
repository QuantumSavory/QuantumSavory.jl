using QuantumClifford.ECC: CSS, parity_checks
using QuantumClifford: stab_to_gf2, graphstate, Stabilizer, MixedDestabilizer, single_x, single_z, logicalxview, logicalzview
using ResumableFunctions
using ConcurrentSim
using Graphs
using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo.MBQCEntanglementDistillation
import QuantumClifford
import QuantumOpticsBase

"""Run the full MBQC purification pipeline described in ["Measurement-Based Entanglement Distillation and Constant-Rate Quantum Repeaters over Arbitrary Distances"](https://journals.aps.org/prl/abstract/10.1103/2bp8-cdxc):
1. Construct graph states on Alice's and Bob's sides
2. Convert graph states to resource states via local Clifford corrections
3. Distribute noisy Bell pairs between Alice and Bob
4. Perform Bell measurements and apply Pauli frame corrections
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

        # Step 2 & 3: Convert to resource states and distribute Bell pairs
        r1 = @process resourceA()
        r2 = @process resourceB()
        entanglers = []
        for i in 1:n
            entangler = EntanglerProt(sim, net, alice_nodes[i], bob_nodes[i];
                pairstate=pairstate,
                chooseslotA=communication_slot, chooseslotB=communication_slot,
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
# Set up the [4,2,2] CSS code.
# The protocol takes an [n,k,d] CSS code and uses n noisy Bell pairs
# to distill k higher-fidelity Bell pairs. In this example, we use n=4, k=2, d=2.
# The parity check matrices H1 (X-type) and H2 (Z-type) define the syndrome measurements,
# and logxs/logzs are the logical X and Z operators used to verify the purified pairs.
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
# Configure and run the simulation.
# Each node has 2 slots: slot 1 (communication) for Bell pair generation via EntanglerProt,
# and slot 2 (storage) for holding the graph state qubit.
# Alice occupies nodes 1..n+k and Bob occupies nodes n+k+1..2*(n+k).
##

perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
communication_slot = 1
storage_slot = 2
alice_nodes = collect(1:n+k)
bob_nodes = collect(n+k+1:2*(n+k))

# Sanity check with perfect Bell pairs: syndrome should always be trivial,
# so purification must succeed every time and the k output pairs must have fidelity 1.
# Here, we check for PurifiedEntanglementCounterpart and calculate the fidelities of the purified pairs.
@info "Checking perfect Bell pairs (initial fidelity = 1): purification must always succeed with output fidelity 1"
t_perfect_start = time()
fidelity = 1
pairstate = noisy_pair_func(perfect_pair, fidelity)
N_perfect_trials = 2
for trial in 1:N_perfect_trials
    @info "Trial $trial:"
    registers = [Register(2) for _ in 1:2*(n+k)]
    net = RegisterNet(registers)
    sim = get_time_tracker(net)

    @process run_purification(sim, net, n, resource_state, alice_nodes, bob_nodes,
        communication_slot, storage_slot, pairstate, H1, H2, logxs, logzs, rounds=1)

    run(sim, 5.0)
    for i in 1:k
        # The last k nodes on each side (indices n+1..n+k) hold the purified logical qubits
        alice_tag = query(net[alice_nodes[n+i]][storage_slot], PurifiedEntanglementCounterpart, ❓, ❓)
        bob_tag = query(net[bob_nodes[n+i]][storage_slot], PurifiedEntanglementCounterpart, ❓, ❓)
        # Both sides must have PurifiedEntanglementCounterpart
        @assert !isnothing(alice_tag)
        @assert !isnothing(bob_tag)
        # Measure fidelity with the ideal Bell state
        f = real(observable((net[alice_nodes[n+i], storage_slot], net[bob_nodes[n+i], storage_slot]), QuantumOpticsBase.projector(perfect_pair)))
        @info "  Purified pair $i: fidelity=$(round(f, digits=4))"
        @assert isapprox(f, 1.0) # Purified pair should be perfect
    end
end

@info "Perfect pairs experiment took $(round(time() - t_perfect_start, digits=2))s"

# Noisy Werner state sweep: for each input fidelity F, collect acceptance rate and output fidelity.
# Results are stored in top-level arrays for use by plots.jl.
N_trials = get(ENV, "QS_TESTRUN", "false") == "true" ? 10 : 100
step = get(ENV, "QS_TESTRUN", "false") == "true" ? 0.1 : 0.05
input_fidelities = collect(0.5:step:1.0)

success_probs_theory = Float64[]
success_probs_empirical = Float64[]
output_fidelities_empirical = Float64[]

@info "Noisy Bell pairs sweep: launching $N_trials simulations per fidelity value"
t_start = time()
for F in input_fidelities
    p_bloch = (4F - 1) / 3
    P_accept_theory = (1 + 3*p_bloch^4) / 4
    push!(success_probs_theory, P_accept_theory)

    n_success = 0
    total_fidelity = 0.0
    for _ in 1:N_trials
        pairstate_noisy = noisy_pair_func(perfect_pair, F)
        regs_trial = [Register(2) for _ in 1:2*(n+k)]
        net_trial = RegisterNet(regs_trial)
        sim_trial = get_time_tracker(net_trial)
        @process run_purification(sim_trial, net_trial, n, resource_state, alice_nodes, bob_nodes,
            communication_slot, storage_slot, pairstate_noisy, H1, H2, logxs, logzs, rounds=1)
        run(sim_trial, 5.0)
        tags = [query(net_trial[alice_nodes[n+i]][storage_slot], PurifiedEntanglementCounterpart, ❓, ❓) for i in 1:k]
        if all(!isnothing, tags)
            n_success += 1
            fidelities = [real(observable([net_trial[alice_nodes[n+i]], net_trial[bob_nodes[n+i]]], [storage_slot, storage_slot], QuantumOpticsBase.projector(perfect_pair))) for i in 1:k]
            total_fidelity += sum(fidelities)
        end
    end

    push!(success_probs_empirical, n_success / N_trials)
    push!(output_fidelities_empirical, n_success > 0 ? total_fidelity / (n_success * k) : NaN)
end
@info "Sweep completed in $(round(time() - t_start, digits=2))s"
