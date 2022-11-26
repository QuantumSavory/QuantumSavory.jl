using Base.Threads
using WGLMakie
WGLMakie.activate!()
using JSServe
using Markdown

include("setup.jl");

"""Run a simulation until all links in the cluster state are established,
then report time to completion and average link fidelity."""
function run_until_connected(root_conf)
    net, sim, observables, conf = prep_sim(root_conf)
    # Run until all connections succeed
    while !all([net[v,:link_register] for v in edges(net)])
        SimJulia.step(sim)
    end
    # Calculate fidelity of each cluster vertex
    fid = map(vertices(net)) do v
        neighs = neighbors(net,v) # get the neighborhood of the vertex
        obs = observables[length(neighs)] # get the observable for the given neighborhood size
        regs = [net[i, 2] for i in [v, neighs...]]
        real(observable(regs, obs; time=now(sim))) # calculate the value of the observable
    end
    now(sim), mean(fid)
end

##
# Prepare functions that can repeatedly run simulations and store the results

const N = 100

function continue_results!(times,fids,current_step,conf_obs,running,max_time)
    timeout = 0
    recent_max_time = 0
    while running[] && timeout<10000
        time, fid = fetch(@spawn run_until_connected(conf_obs[])) # do not run heavy calculations on the main thread, even if async
        recent_max_time = max(0.99*recent_max_time, time)
        max_time[] = max_time[]*0.998 + recent_max_time*0.002
        times[][current_step[]] = time
        fids[][current_step[]] = fid
        current_step[] = current_step[]%N+1
        timeout+=1
        notify(times)
        notify(fids)
    end
    running[] = false
end

function fill_results!(times,fids,conf)
    for i in 1:length(times[])
        time, fid = run_until_connected(conf)
        times[][i] = time
        fids[][i] = fid
    end
end

def_times = Observable(zeros(Float64, N))
def_fids = Observable(zeros(Float64, N))

fill_results!(def_times,def_fids,root_conf)

##
# Prepare the Makie app

app = App() do
    times = Observable(zeros(Float64, N))
    fids = Observable(zeros(Float64, N))
    times[] .= def_times[]
    fids[] .= def_fids[]
    max_time = Observable(maximum(def_times[]))
    current_step = Ref(1)
    conf = Observable(deepcopy(root_conf))

    # Plot the time to complete vs average fidelity

    F = Figure(resolution=(1200,600))
    F1 = F[1,1]
    ax = Axis(F1[2:5,1:4])
    ax_time = Axis(F1[1,1:4])
    ax_fid = Axis(F1[2:5,5])
    linkxaxes!(ax,ax_time)
    linkyaxes!(ax,ax_fid)
    ylims!(ax, 0-0.02, 1+0.02)
    scatter!(ax, times, fids)
    hist!(ax_time, times, bins=15, normalization=:probability)
    hist!(ax_fid, fids, direction=:x, bins=15, normalization=:probability)
    ylims!(ax_time, 0, 0.2)
    xlims!(ax_time, 0, 1.2*max_time[])
    on(max_time) do t; xlims!(ax_time, 0, 1.2*t) end
    xlims!(ax_fid, 0, 0.2)
    hideydecorations!(ax_time)
    hidexdecorations!(ax_fid)
    ax.ylabel = "Fidelity of Completed Cluster"
    ax.xlabel = "Time to Prepare Complete Cluster (ms)"

    F[2, 1:2] = buttongrid = GridLayout(tellwidth = false)
    running = Observable(false)
    buttongrid[1,1] = b = Makie.Button(F, label = @lift($running ? "Stop" : "Run"))

    on(b.clicks) do _
        running[] = !running[]
    end
    on(running) do r
        r && @async continue_results!(times,fids,current_step,conf,running,max_time)
    end

    sg = SliderGrid(
        F[1, 2],
        (label = "Raw Entanglement Fidelity", #BK_electron_entanglement_fidelity
            range = 0.85:0.005:1.0, format = "{:.2f}", startvalue = root_conf.BK_electron_entanglement_fidelity),
        #-> "BK_electron_entanglement_init_state",

        (label = "coincidence measurement fidelity", #BK_measurement_fidelity
            range = 0.85:0.005:1.0, format = "{:.2f}", startvalue = root_conf.BK_measurement_fidelity),

        (label = "optical circuit efficiency", #losses
            range = 0.01:0.01:1.0, format = "{:.2f}", startvalue = root_conf.losses),
        (label = "ξ optical branching",
            range = 0.5:0.01:1.0, format = "{:.2f}", startvalue = root_conf.ξ_optical_branching),
        (label = "ξ Debye-Waller",
            range = 0.5:0.01:1.0, format = "{:.2f}", startvalue = root_conf.ξ_debye_waller),
        (label = "ξ quantum efficiency",
            range = 0.5:0.01:1.0, format = "{:.2f}", startvalue = root_conf.ξ_quantum_efficiency),
        (label = "F Purcell",
            range = 1:100, format = "{:.2f}", startvalue = root_conf.F_purcell),
        #-> BK_total_efficiency -> BK_success_prob -> BK_success_distribution

        (label = "Barret-Kok attempt duration (ms)", #BK_electron_entanglement_gentime
            range = 0.001:0.001:0.1, format = "{:.3f}", startvalue = root_conf.BK_electron_entanglement_gentime),
        (label = "hyperfine coupling (kHz)", #hyperfine_coupling
            range = 5e3:1e3:50e3, format = "{:.2f}", startvalue = root_conf.hyperfine_coupling),

        width = 600,
        tellheight = false)

    names = [:BK_electron_entanglement_fidelity, :BK_measurement_fidelity, :losses, :ξ_optical_branching, :ξ_debye_waller, :ξ_quantum_efficiency, :BK_electron_entanglement_gentime, :hyperfine_coupling]
    for (name,slider) in zip(names,sg.sliders)
        on(slider.value) do val
            conf[] = (;conf[]..., NamedTuple{(name,)}((val,))...)
        end
    end

    dom = md"""$(F.scene)
    # Simulations of the generation of 3×2 cluster states in Tin-vacancy color centers

    Each dot in the plot corresponds to one complete Monte Carlo simulation run.

    The overall fidelity of the generated cluster state is on the vertical axis.
    The time necessary for the completion of the experiment is on the horizontal axis.
    Histograms of these values are given in the side facets.

    To the right you can modify various hardware parameters live, while the simulation is running.
    Press "Run" to start the simulation. Only the last $(N) simulation results are shown.

    The plots zoom automatically to the regions of interest.
    Drag over the plot to select manual region to zoom in.
    `Ctrl`+click resets the view.

    ## A few hardcoded values

    Mostly taken from `10.1103/PhysRevLett.124.023602` and `10.1103/PhysRevX.11.041041`.
    For the nuclear spins we reused some NV⁻ data.

    - spin lifetimes (in ms)
        - electron T₁ = $(root_conf.T1E) (with cooling)
        - electron T₂ = $(root_conf.T2E) (with dynamical decoupling)
        - nuclear T₁ = $(root_conf.T1N) (generally very large, basically neglected)
        - nuclear T₁ = $(root_conf.T2N) (with dynamical decoupling)
    - the nuclear-electronic SWAP gate is 10 times slower than the hyperfine coupling

    ## A few things that are not modeled in detail

    But are easy to add when we get around to it...

    - time gating of the detectors might be quite important but it is not used
        - it would increase fidelity
        - it would decrease efficiency
    - mismatches between emitters (random or systematic) are lumped into "raw entanglement fidelity"
    - detector dark counts and other imperfections are lumped into "coincidence measurement fidelity"
    - most single-qubit gate times and fidelities are neglected
    - initialization of the nuclear and electronic spins is not modeled in detail
    - bleaching and charge state instability are not modeled
    - dead time from reconfiguring optical paths is not modeled
    - crosstalk in microwave control is not modeled
    - optical crosstalk and poor extinction are not modeled
    - decoupling the electronic and nuclear spin after a failed measurement is not modeled in detail
    """
    return JSServe.DOM.div(JSServe.MarkdownCSS, JSServe.Styling, dom)
end

##
# Serve the Makie app

server = JSServe.get_server()
JSServe.route!(server, "/" => app)
wait(server.server_task[])
