using WGLMakie
WGLMakie.activate!()
using JSServe
using Markdown

include("setup.jl")

const custom_css = JSServe.DOM.style("ul {list-style: circle !important;}") # TODO remove after fix of bug in JSServe https://github.com/SimonDanisch/JSServe.jl/issues/178

##
# Demo visualizations of the performance of the network
##

function prepare_singlerun(
    fig;
    len = 5,                    # Number of registers in the chain
    regsize = 2,                # Number of qubits in each register
    T2 = 100.0,                 # T2 dephasing time of all qubits
    F = 0.97,                   # Fidelity of the raw Bell pairs
    entangler_wait_time = 0.1,  # How long to wait if all qubits are busy before retring entangling
    entangler_busy_λinv = 0.5,  # How long it takes to establish a newly entangled pair (Exponential distribution parameter)
    swapper_wait_time = 0.1,    # How long to wait if all qubits are unavailable for swapping
    swapper_busy_time = 0.55,   # How long it takes to swap two qubits
    consume_wait_time = 0.1,    # How long to wait if there are no qubits ready for consumption
)
    sim, network = simulation_setup(len, regsize, T2)

    noisy_pair = noisy_pair_func(F)
    for (;src, dst) in edges(network)
        @process entangler(sim, network, src, dst, noisy_pair, entangler_wait_time, 1/entangler_busy_λinv)
    end

    for node in vertices(network)
        @process swapper(sim, network, node, swapper_wait_time, swapper_busy_time)
    end

    ts = Observable(Float64[])
    fidXX = Observable(Float64[])
    fidZZ = Observable(Float64[])
    @process consumer(sim, network, 1, len, consume_wait_time,ts,fidXX,fidZZ)

    registercoords = [Point2{Float64}(2*cos(pi/(len+1)*i),sin(pi/(len+1)*i)).*(regsize+2) for i in 1:len]
    _,ax,_,obs = registernetplot_axis(fig[1,1],network; interactions=false, registercoords)

    ax_fidXX = Axis(fig[1,2][1,1], xlabel="", ylabel="XX Stabilizer\nExpectation")
    ax_fidZZ = Axis(fig[1,2][2,1], xlabel="time", ylabel="ZZ Stabilizer\nExpectation")
    c1 = Makie.wong_colors()[1]
    c2 = Makie.wong_colors()[2]
    scatter!(ax_fidXX,ts,fidXX,label="XX",color=(c1,0.1))
    scatter!(ax_fidZZ,ts,fidZZ,label="ZZ",color=(c2,0.1))

    sim, network, obs, ts, ax, ax_fidXX, ax_fidZZ
end

function continue_singlerun!(sim, network, observables, axes, running)
    step_ts = range(0, 1000, step=0.1)
    for t in step_ts
        run(sim, t)
        # axes[1].title = "t=$(t)" # TODO does not update consistently
        notify.(observables)
        autolimits!.(axes)
    end
    running[] = nothing
end

##

landing = App() do
    fig = Figure(resolution=(800,700))

    fig[1, 1] = buttongrid = GridLayout(tellwidth = false)

    running = Observable{Any}(false)
    buttongrid[1,1] = b = Makie.Button(fig, label = @lift(isnothing($running) ? "Done" : $running ? "Running..." : "Run once"))
    conf_obs = add_conf_sliders(fig[1,2])

    on(b.clicks) do _
        if !running[]
            running[] = true
        end
    end
    on(running) do r
        if r
            sim, network, obs, ts, ax, ax_fidXX, ax_fidZZ = prepare_singlerun(fig[2,1:2]; conf_obs[]...)
            Threads.@spawn continue_singlerun!(sim, network, (obs, ts), (ax, ax_fidXX, ax_fidZZ), running)
        end
    end

    content = md"""
    Pick simulation settings and hit run (see below for technical details).

    $(fig.scene)

    # Simulations of a chain of repeaters

    Two processes occur in this system

    - nearest neighbors have entanglement being generated between them
    - each repeater performs an entanglement swap as soon as possible

    In this simulation you can manipulate:
    - number of repeaters
    - number of qubits available as memories at each repeater
    - the mean time to successful generation of a raw Bell pair (governed by an exponential distribution)
    - the time it takes to perform a swap at a reapeater
    - the fidelity of a raw Bell pair (assuming depolarization noise)
    - T₂ memory time (only dephasing is modeled)

    Local gates are assumed perfect.

    To avoid deadlocks, entangled pairs are being generated only on even/odd pair of registers:
    for a given pair of neighboring repeaters a raw entagled pair can be stored only in odd registers
    on the left repeater and in even registers on the right repeater.
    This staggering makes it impossible for the concurrent processes of entangling generation and swapping
    to deadlock each other.

    This simulation is a convenient tool for studying congestion on the repeater chain.

    [See and modify the code for this simulation on github.](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/congestionchain)
    """
    return DOM.div(JSServe.MarkdownCSS, JSServe.Styling, custom_css, content)
end;


##
# A helper to add parameter sliders to visualizations

function add_conf_sliders(fig)
    conf = Dict(
        :len => 5,
        :regsize => 2,
        :T2 => 100.0,
        :F => 0.97,
        :entangler_busy_λinv => 0.5,
        :swapper_busy_time => 0.5
    )
    conf_obs = Observable(conf)
    sg = SliderGrid(
        fig,
        (label = "repeater chain length",
            range = 3:1:10, format = "{:d}", startvalue = conf[:len]),

        (label = "repeater size (nb of qubits)",
            range = 2:1:5, format = "{:d}", startvalue = conf[:regsize]),

        (label = "T₂ of memories",
            range = 1.0:10.:500.0, format = "{:.1f}", startvalue = conf[:T2]),
        (label = "fidelity of raw pairs",
            range = 0.6:0.01:1.0, format = "{:.2f}", startvalue = conf[:F]),
        (label = "avg. time of ent. generation",
            range = 0.05:0.05:1.0, format = "{:.2f}", startvalue = conf[:entangler_busy_λinv]),
        (label = "swap duration",
            range = 0.05:0.05:1.0, format = "{:.2f}", startvalue = conf[:swapper_busy_time]),
        width = 600,
        #tellheight = false
    )

    # TODO there should be a nicer way to link sliders to the configuration
    names = [:len, :regsize, :T2, :F, :entangler_busy_λinv, :swapper_busy_time]
    for (name,slider) in zip(names,sg.sliders)
        on(slider.value) do val
            conf_obs[][name] = val
        end
    end
    conf_obs
end

##
# Serve the Makie app

isdefined(Main, :server) && close(server);
port = parse(Int, get(ENV, "QS_CONGENSTIONCHAIN_PORT", "8888"))
interface = get(ENV, "QS_CONGENSTIONCHAIN_IP", "127.0.0.1")
proxy_url = get(ENV, "QS_CONGENSTIONCHAIN_PROXY", "")
server = JSServe.Server(interface, port; proxy_url);
JSServe.HTTPServer.start(server)
JSServe.route!(server, "/" => landing);

##

wait(server)
