include("setup.jl")

controller = NetController(sim, net, 3, 6, 0.2)
@process controller()

consumer = EntanglementConsumer(sim, net, 1, 8; period=0.2)
@process consumer()

for node in 1:7
    tracker = RequestTracker(sim, net, node, 0.3)
    @process tracker()
end

for v in 1:8
    tracker = EntanglementTracker(sim, net, v)
    @process tracker()
end

for v in 1:8
    c_prot = CutoffProt(sim, net, v)
    @process c_prot()
end

sim, net, obs, entlog, entlogaxis, fid_axis, histaxis, num_epr_axis, fig = prepare_vis(consumer)

step_ts = range(0.0, 1000.0, step=0.1)
record(fig, "sim.mp4", step_ts; framerate=10, visible=true) do t
    run(sim, t)
    notify.((obs,entlog))
    ylims!(entlogaxis, (-1.04,1.04))
    xlims!(entlogaxis, max(0,t-50), 1+t)
    ylims!(fid_axis, (0, 1.04))
    xlims!(fid_axis, max(0, t-50), 1+t)
    autolimits!(histaxis)
    ylims!(num_epr_axis, (0, 4))
    xlims!(num_epr_axis, max(0, t-50), 1+t)
end