# Interactive GLMakie visualization for the Butterfly Network Coding example
# Compares classical routing bottleneck vs quantum network coding

using GLMakie
GLMakie.activate!()

include("setup.jl")

"""
Prepare the simulation and visualization for a single run.
mode can be :classical or :coding
"""
function prepare_run(fig; mode=:classical, regsize=4, T2=100.0, F=0.95)
    sim, network = simulation_setup(; regsize, T2)
    
    noisy_pair = noisy_pair_func(F)
    
    # Start entanglement generation on all edges
    for (;src, dst) in edges(network)
        @process entangler(sim, network, src, dst, noisy_pair, 0.1, 0.5)
    end
    
    # Start swappers on router nodes (3 and 4)
    # In classical mode, standard swapper. In coding mode, we'd use a specialized coder.
    # For now, we use the standard swapper to demonstrate the baseline routing.
    for node in [3, 4]
        @process swapper(sim, network, node, 0.1, 0.55, mode)
    end
    
    # Consumers at the sinks (T1=5, T2=6)
    ts1 = Observable(Float64[])
    fidXX1 = Observable(Float64[])
    fidZZ1 = Observable(Float64[])
    @process consumer(sim, network, 1, 5, 0.1, ts1, fidXX1, fidZZ1)
    
    ts2 = Observable(Float64[])
    fidXX2 = Observable(Float64[])
    fidZZ2 = Observable(Float64[])
    @process consumer(sim, network, 2, 6, 0.1, ts2, fidXX2, fidZZ2)
    
    # Layout for butterfly network
    # S1(1) at top-left, S2(2) at bottom-left
    # A(3) at mid-left, B(4) at mid-right
    # T1(5) at top-right, T2(6) at bottom-right
    registercoords = [
        Point2f(-2, 1),   # 1: S1
        Point2f(-2, -1),  # 2: S2
        Point2f(0, 0),    # 3: A
        Point2f(2, 0),    # 4: B
        Point2f(4, 1),    # 5: T1
        Point2f(4, -1)    # 6: T2
    ] .* 100
    
    _, ax_net, _, obs_net = registernetplot_axis(fig[1,1], network; interactions=false, registercoords)
    ax_net.title = "Butterfly Network ($(mode) mode)"
    
    # Fidelity plots for T1
    ax_fid1 = Axis(fig[1,2], xlabel="time", ylabel="Fidelity (T1)", title="Sink T1 (from S1)")
    scatter!(ax_fid1, ts1, fidZZ1, label="ZZ", color=:blue, markersize=5)
    scatter!(ax_fid1, ts1, fidXX1, label="XX", color=:red, markersize=5)
    axislegend(ax_fid1)
    
    # Fidelity plots for T2
    ax_fid2 = Axis(fig[2,2], xlabel="time", ylabel="Fidelity (T2)", title="Sink T2 (from S2)")
    scatter!(ax_fid2, ts2, fidZZ2, label="ZZ", color=:blue, markersize=5)
    scatter!(ax_fid2, ts2, fidXX2, label="XX", color=:red, markersize=5)
    axislegend(ax_fid2)
    
    return sim, network, (obs_net, ts1, fidXX1, fidZZ1, ts2, fidXX2, fidZZ2), (ax_net, ax_fid1, ax_fid2)
end

function continue_run!(sim, network, observables, axes, running; step_ts = range(0, 200, step=10.0))
    for t in step_ts
        run(sim, t)
        notify.(observables)
        autolimits!.(axes)
        yield()
    end
    running[] = false
end

# Main App
fig = Figure(size=(1200, 800))
running = Observable(false)

mode_obs = Observable(:classical)

# Controls
fig[0, 1:2] = buttongrid = GridLayout(tellwidth=false)
run_btn = Button(fig, label="Run Simulation")
buttongrid[1, 1] = run_btn

mode_menu = Menu(fig, options=["classical", "coding"], default="classical")
buttongrid[1, 2] = mode_menu

on(mode_menu.selection) do s
    mode_obs[] = Symbol(s)
end

on(run_btn.clicks) do _
    if !running[]
        running[] = true
        empty!(fig[1, 1])
        empty!(fig[1, 2])
        empty!(fig[2, 2])
        
        sim, network, obs, axes = prepare_run(fig; mode=mode_obs[])
        @async continue_run!(sim, network, obs, axes, running)
    end
end

# Initial static plot
sim, network, obs, axes = prepare_run(fig; mode=:classical)

fig
