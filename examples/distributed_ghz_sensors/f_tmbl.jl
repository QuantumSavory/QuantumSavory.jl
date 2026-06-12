include("setup.jl")

"""Run the F-TMBL (Fixed-Time Multiplexing Block Length).
Performs a single GHZ projection on whatever links succeeded after a fixed time."""
@resumable function f_tmbl(sim, net, S, fixed_time, attempt_time, success_prob, pairstate, result)
    hub_idx = S + 1

    procs = map(1:S) do i
        eprot = EntanglerProt(sim, net, i, hub_idx; pairstate, chooseslotA=1, chooseslotB=i,
                              success_prob, attempt_time,
                              attempts=round(Int, fixed_time/attempt_time), # notr super exact
                              rounds=1)
        @process eprot()
    end
    for p in procs  # wait for the whole window to elapse before querying
        @yield p
    end

    ent = entangled_sensors(net, S)
    if isempty(ent)
        @info "  F-TMBL: all entanglement failed at t=$(now(sim))"
    else
        @info "  F-TMBL: $(length(ent)) sensors entangled at t=$(now(sim)): $ent"
        ghz_project(net, S, ent)
    end
    result[] = ent
end

##
# Configure and run the simulation.
##

fixed_time = 0.25 # entanglement-generation window
@info "F-TMBL run: S=$S, F=$F, p=$success_prob, fixed_time=$fixed_time"
t_start = time()

net = build_sensor_net(S)
sim = get_time_tracker(net)

result = Ref(Int[])

for i in 1:S  # trackers apply the incoming corrections at each sensor
    @process EntanglementTracker(sim, net, i)()
end

@process f_tmbl(sim, net, S, fixed_time, attempt_time, success_prob, noisy_pair, result)
run(sim, fixed_time + 1)

@info "F-TMBL result: entangled $(length(result[]))/$S sensors, GHZ fidelity = $(round(ghz_fidelity(net, result[]), digits=4))"
@info "F-TMBL run took $(round(time() - t_start, digits=2))s"