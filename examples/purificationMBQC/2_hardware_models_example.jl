include("setup.jl")

using QuantumSavory.StatesZoo: BarrettKokBellPair
using QuantumSavory.StatesZoo.Genqo: GenqoMultiplexedCascadedBellPairW
using LinearAlgebra: tr

# local correction gates applied to Alice's / node-B communication qubit after heralding
zalm_correction = [Z]      # `-XX ZZ` → `XX ZZ`
bk_correction   = [X, H]   # `XX -ZZ` → graph form `XZ ZX`

function run_hardware_trials(n_trials, zalm_pairstate, bk_pairstate)
    n_success = 0
    total_fidelity = 0.0
    for _ in 1:n_trials
        regs_trial = [Register(2) for _ in 1:2*(n+k)]
        net_trial = RegisterNet(regs_trial)
        sim_trial = get_time_tracker(net_trial)
        @process run_purification(sim_trial, net_trial, n, resource_state, alice_nodes, bob_nodes,
            communication_slot, storage_slot, H1, H2, logxs, logzs,
            rounds=1, long_range_pairstate=zalm_pairstate, long_range_correction=zalm_correction,
            local_pairstate=bk_pairstate, local_correction=bk_correction)
        run(sim_trial, 100.0)
        tags = [query(net_trial[alice_nodes[n+i]][storage_slot], PurifiedEntanglementCounterpart, ❓, ❓) for i in 1:k]
        if all(!isnothing, tags)
            n_success += 1
            fidelities = [real(observable([net_trial[alice_nodes[n+i]], net_trial[bob_nodes[n+i]]], [storage_slot, storage_slot], QuantumOptics.projector(perfect_pair))) for i in 1:k]
            total_fidelity += sum(fidelities)
        end
    end
    acceptance = n_success / n_trials
    mean_out_f = n_success > 0 ? total_fidelity / (n_success * k) : NaN
    return acceptance, mean_out_f
end

##
# Sanity check with near-ideal hardware: lossless Barrett-Kok links and a lossless
# ZALM source should reproduce the perfect-pair result (fidelity 1 after purification).
##

@info "Checking near-ideal hardware: purification must succeed with output fidelity ≈ 1"
t_ideal_start = time()
bk_ideal = BarrettKokBellPair(1.0, 1.0, 0.0, 1.0, 1.0)
zalm_ideal_w = GenqoMultiplexedCascadedBellPairW(1.0, 1.0, 1.0, 0.1, 0.0)
zalm_ideal = zalm_ideal_w / real(tr(express(zalm_ideal_w)))
acceptance_ideal, out_f_ideal = run_hardware_trials(2, zalm_ideal, bk_ideal)
@info "Near-ideal hardware: acceptance=$(acceptance_ideal), output fidelity=$(round(out_f_ideal, digits=4))"
@assert acceptance_ideal == 1.0
@assert isapprox(out_f_ideal, 1.0; atol=1e-6)
@info "Near-ideal hardware experiment took $(round(time() - t_ideal_start, digits=2))s"