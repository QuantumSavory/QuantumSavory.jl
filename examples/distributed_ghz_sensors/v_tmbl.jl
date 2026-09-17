include("setup.jl")

"""Run the V-TMBL (Variable-Time Multiplexing Block Length) protocol.
The sensors keep attempting entanglement until at least μ links have succeeded,
then the hub immediately performs the GHZ projection."""
@resumable function v_tmbl(sim, net, S, μ, attempt_time, success_prob, pairstate, result)
    hub_idx = S + 1

    for i in 1:S
        eprot = EntanglerProt(sim, net, i, hub_idx; pairstate, chooseslotA=1, chooseslotB=i,
                              success_prob, attempt_time, attempts=-1, rounds=1)
        @process eprot()
    end

    # Poll the hub until at least μ sensors are entangled
    ent = entangled_sensors(net, S)
    while length(ent) < μ
        @yield onchange(net[hub_idx])  # entanglement has been established
        ent = entangled_sensors(net, S)
    end

    @debug(
        "Reached the entanglement target",
        _group=LOG_GROUPS.protocol,
        event=:entanglement_target_reached,
        simulation_log_context(sim)...,
        protocol=:v_tmbl,
        nodes=(Tuple(1:S)..., hub_idx),
        client_nodes=Tuple(ent),
        target=μ,
    )
    ghz_project(net, S, ent)
    result[] = ent
end

##
# Configure and run the simulation.
##

μ = 3  # minimum number of entangled sensors before projecting

@info "V-TMBL: S=$S, F=$F, p=$success_prob, μ=$μ"
t_start = time()

net = build_sensor_net(S)
sim = get_time_tracker(net)

result = Ref(Int[])

for i in 1:S  # trackers apply the incoming corrections at each sensor
    @process EntanglementTracker(sim, net, i)()
end

@process v_tmbl(sim, net, S, μ, attempt_time, success_prob, noisy_pair, result)
run(sim, 10)

@info "V-TMBL result: entangled $(length(result[]))/$S sensors (μ=$μ), GHZ fidelity = $(round(ghz_fidelity(net, result[]), digits=4))"
@info "V-TMBL run took $(round(time() - t_start, digits=2))s"
