include("setup.jl")

using QuantumSavory.StatesZoo: DepolarizedBellPair

##
# Configure and run the simulation with depolarized (Werner-state) Bell pairs.
##

# Sanity check with perfect Bell pairs: syndrome should always be trivial,
# so purification must succeed every time and the k output pairs must have fidelity 1.
# Here, we check for PurifiedEntanglementCounterpart and calculate the fidelities of the purified pairs.
@info "Checking perfect Bell pairs (initial fidelity = 1): purification must always succeed with output fidelity 1"
t_perfect_start = time()
pairstate = DepolarizedBellPair(F=1)
N_perfect_trials = 2
for trial in 1:N_perfect_trials
    @info "Trial $trial:"
    registers = [Register(2) for _ in 1:2*(n+k)]
    net = RegisterNet(registers)
    sim = get_time_tracker(net)

    @process run_purification(sim, net, n, resource_state, alice_nodes, bob_nodes,
        communication_slot, storage_slot, H1, H2, logxs, logzs,
        rounds=1, long_range_pairstate=pairstate)

    run(sim, 5.0)
    for i in 1:k
        # The last k nodes on each side (indices n+1..n+k) hold the purified logical qubits
        alice_tag = query(net[alice_nodes[n+i]][storage_slot], PurifiedEntanglementCounterpart, ❓, ❓)
        bob_tag = query(net[bob_nodes[n+i]][storage_slot], PurifiedEntanglementCounterpart, ❓, ❓)
        # Both sides must have PurifiedEntanglementCounterpart
        @assert !isnothing(alice_tag)
        @assert !isnothing(bob_tag)
        # Measure fidelity with the ideal Bell state
        f = real(observable((net[alice_nodes[n+i], storage_slot], net[bob_nodes[n+i], storage_slot]), QuantumOptics.projector(perfect_pair)))
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
    pairstate_noisy = DepolarizedBellPair(;F)
    for _ in 1:N_trials
        regs_trial = [Register(2) for _ in 1:2*(n+k)]
        net_trial = RegisterNet(regs_trial)
        sim_trial = get_time_tracker(net_trial)
        @process run_purification(sim_trial, net_trial, n, resource_state, alice_nodes, bob_nodes,
            communication_slot, storage_slot, H1, H2, logxs, logzs,
            rounds=1, long_range_pairstate=pairstate_noisy)
        run(sim_trial, 5.0)
        tags = [query(net_trial[alice_nodes[n+i]][storage_slot], PurifiedEntanglementCounterpart, ❓, ❓) for i in 1:k]
        if all(!isnothing, tags)
            n_success += 1
            fidelities = [real(observable([net_trial[alice_nodes[n+i]], net_trial[bob_nodes[n+i]]], [storage_slot, storage_slot], QuantumOptics.projector(perfect_pair))) for i in 1:k]
            total_fidelity += sum(fidelities)
        end
    end

    push!(success_probs_empirical, n_success / N_trials)
    push!(output_fidelities_empirical, n_success > 0 ? total_fidelity / (n_success * k) : NaN)
end
@info "Sweep completed in $(round(time() - t_start, digits=2))s"
