include("setup.jl")

succ_prob = Observable(0.001)
for (;src, dst) in edges(net)
    eprot = EntanglerProt(sim, net, src, dst; rounds=-1, randomize=true, success_prob=succ_prob[])
    @process eprot()
end

local_busy_time = Observable(0.0)
retry_lock_time = Observable(0.1)
for node in 2:7
    swapper = SwapperProt(sim, net, node; nodeL = <(node), nodeH = >(node), chooseL = argmin, chooseH = argmax, rounds=-1, local_busy_time=local_busy_time[],
    retry_lock_time=retry_lock_time[])
    @process swapper()
end

for v in vertices(net)
    tracker = EntanglementTracker(sim, net, v)
    @process tracker()
end

period_cons = Observable(0.1)
consumer = EntanglementConsumer(sim, net, 1, 8; period=period_cons[])
@process consumer()

period_dec = Observable(0.1)
for v in vertices(net)
    cutoff = CutoffProt(sim, net, v; period=period_dec[])
    @process cutoff()
end
params = [succ_prob, local_busy_time, retry_lock_time, period_cons, period_dec]
sim, net, obs, entlog, entlogaxis, fid_axis, histaxis, num_epr_axis, fig = prepare_vis(consumer, params)

step_ts = range(0.0, 1000.0, step=0.1)
record(fig, "sim.mp4", step_ts; framerate=10, visible=true) do t
    run(sim, t)
    notify.((obs,entlog))
    notify.(params)
    ylims!(entlogaxis, (-1.04,1.04))
    xlims!(entlogaxis, max(0,t-50), 1+t)
    ylims!(fid_axis, (0, 1.04))
    xlims!(fid_axis, max(0, t-50), 1+t)
    autolimits!(histaxis)
    ylims!(num_epr_axis, (0, 4))
    xlims!(num_epr_axis, max(0, t-50), 1+t)
end