# Live visualization of the piecemaker switch protocol
using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumClifford: ghz
using Graphs
using ConcurrentSim
using ResumableFunctions
using DataFrames
using Random

using Base.Threads
using WGLMakie
WGLMakie.activate!()

using Bonito
using Markdown
const custom_css = Bonito.DOM.style("ul {list-style: circle !important;}")

const ghzs = [ghz(n) for n in 1:7]  # precompute GHZ targets
const fidelity_points = Observable(Point2f[]) # for live plotting

"""
    fusion(piecemaker_slot, client_slot) -> Int

Fuse the client's switch-side qubit into the piecemaker via CNOT, then project
and trace out the client in the Z basis. Returns the projective outcome (1 or 2).

- Arguments:
  - piecemaker_slot: Qubit register slot at the switch (the piecemaker).
  - client_slot: Qubit register slot at the switch for the given client.
- Behavior: apply!((piecemaker_slot, client_slot), CNOT); project_traceout!(client_slot, σᶻ).
- Returns: Int in {1, 2}, used to decide an X correction at the client.
"""
function fusion(piecemaker_slot, client_slot)
    apply!((piecemaker_slot, client_slot), CNOT)
    res = project_traceout!(client_slot, σᶻ)
    return res
end

"""
    EntanglementCorrector(sim, net, node)

Resumable process that waits for a Tag(:updateX, outcome) at `node`.
Locks the node’s qubit, applies X if `outcome == 2`, unlocks, and terminates.

- Arguments:
  - sim: ConcurrentSim time tracker.
  - net: RegisterNet with registers per node.
  - node: Client node index (1-based in `net`).
- Behavior: listens for :updateX on `net[node][1]`, ensures thread-safety via lock.
"""
@resumable function EntanglementCorrector(sim, net, node)
    while true
        @yield onchange_tag(net[node][1])
        msg = querydelete!(net[node][1], :updateX, ❓)
        if !isnothing(msg)
            value = msg[3][2]
            @yield lock(net[node][1])
            @debug "X received at node $(node), with value $(value)"
            value == 2 && apply!(net[node][1], X)
            unlock(net[node][1])
            break
        end
    end
end

"""
    Logger(sim, net, node, n, logging, start_of_round, net_obs)

Resumable process that waits for Tag(:updateZ, outcome) at `node`, applies a Z
correction if needed, computes fidelity to the n-qubit GHZ target, logs it, and
updates the live plot and network view.

- Arguments:
  - sim: ConcurrentSim time tracker.
  - net: RegisterNet.
  - node: Node index that receives the final X-basis measurement outcome.
  - n: Number of clients/qubits in the GHZ state.
  - logging: DataFrame to push (Δt, fidelity) rows.
  - start_of_round: Simulation time when the round started.
  - net_obs: Observable from registernetplot_axis to force redraws.
- Returns: nothing, updates `fidelity_points` and `logging`.
"""
@resumable function Logger(sim, net, node, n, logging, start_of_round, net_obs)
    msg = querydelete!(net[node], :updateZ, ❓)
    if isnothing(msg)
        error("No message received at node $(node) with tag :updateZ.")
    else
        value = msg[3][2]
        @debug "Z received at node $(node), with value $(value)"
        @yield lock(net[node][1])
        value == 2 && apply!(net[node][1], Z)
        unlock(net[node][1])

        # Measure fidelity to GHZ
        @yield reduce(&, [lock(q) for q in net[2]])
        obs_proj = SProjector(StabilizerState(ghzs[n]))
        fidelity = real(observable([net[i+1][1] for i in 1:n], obs_proj; time = now(sim)))
        t = now(sim) - start_of_round
        @info "Fidelity: $(fidelity)"
        push!(logging, (t, fidelity))

        sleep(0.5) # slow down so network state change is visible
        notify(net_obs)  # show post-measurement state
        sleep(0.5)

        # live update
        push!(fidelity_points[], Point2f(t, fidelity))
        notify(fidelity_points)
    end
end

"""
    PiecemakerProt(sim, n, net, link_success_prob, logging, rounds, net_obs)

Piecemaker protocol for `n` clients. Repeatedly attempts link generation, fuses successful links into the piecemaker,
measures the piecemaker in X, triggers final correction via `Logger`, and logs fidelity.

- Arguments:
  - sim: ConcurrentSim time tracker.
  - n: Number of clients.
  - net: RegisterNet (star topology: switch + clients).
  - link_success_prob: Per-attempt success probability for heralded links.
  - logging: DataFrame to record (Δt, fidelity).
  - rounds: Number of rounds to run (typically 1 per button click in the UI).
  - net_obs: Observable from registernetplot_axis to force redraws.
- Note: Uses `EntanglerProt` for attempts and `fusion` for CNOT+Z projection.
"""
@resumable function PiecemakerProt(sim, n, net, link_success_prob, logging, rounds, net_obs)
    while rounds != 0
        @info "round $(rounds)"
        start = now(sim)

        # entangle each client with its designated switch slot i
        for i in 1:n
            entangler = EntanglerProt(
                sim = sim, net = net, nodeA = 1, chooseA = i, nodeB = 1 + i, chooseB = 1,
                success_prob = link_success_prob, rounds = 1, attempts = -1, attempt_time = 1.0,
            )
            @process entangler()
        end

        for i in 1:n
            @process EntanglementCorrector(sim, net, 1 + i)
        end

        while true
            counter = 0
            while counter < n
                @yield onchange_tag(net[1])
                if counter == 0
                    # Initialize piecemaker |+> (slot n+1 at the switch)
                    initialize!(net[1][n+1], X1, time = now(sim))
                end

                while true
                    counterpart = querydelete!(net[1], EntanglementCounterpart, ❓, ❓)
                    if !isnothing(counterpart)
                        slot, _, _ = counterpart

                        # At this point the link (switch slot i) <-> (client i) exists -> show it
                        notify(net_obs)
                        sleep(0.5)   # slow down so the link appearance is visible

                        @yield lock(net[1][n+1]) & lock(net[1][slot.idx])
                        res = fusion(net[1][n+1], net[1][slot.idx])
                        unlock(net[1][n+1]); unlock(net[1][slot.idx])

                        tag!(net[1 + slot.idx][1], Tag(:updateX, res))
                        counter += 1
                        @debug "Fused client $(slot.idx) with piecemaker qubit"

                        # After fusion, the entanglement “moves” to include the piecemaker slot.
                        notify(net_obs)
                        sleep(0.5)
                    else
                        break
                    end
                end
            end

            @debug "All clients entangled, measuring piecemaker | time: $(now(sim)-start)"
            @yield lock(net[1][n+1])
            res = project_traceout!(net[1][n+1], σˣ)
            unlock(net[1][n+1])
            tag!(net[2][1], Tag(:updateZ, res))
            break
        end

        @yield @process Logger(sim, net, 2, n, logging, start, net_obs)

        # cleanup qubits
        foreach(q -> (traceout!(q); unlock(q)), net[1])
        foreach(q -> (traceout!(q); unlock(q)), [net[1 + i][1] for i in 1:n])
        notify(net_obs)

        rounds -= 1
        @debug "Round $(rounds) finished"
    end

    sleep(0.7)
    if rounds > 0
        fidelity_points[] = Point2f[]  # clear points for next round
    end
    notify(fidelity_points)
end

"""
    prepare_sim(fig, n, link_success_prob, mem_depolar_prob, seed) -> (sim, net, logging)

Build the star network (switch + `n` clients), attach the live network plot into `fig[1,2]`,
configure plotting limits and interactions, start the protocol process, and return the
simulation handle.

- Arguments:
  - fig: Makie Figure; network view is placed into `fig[1,2]`.
  - n: Number of clients (and GHZ size).
  - link_success_prob: Per-attempt entanglement success probability.
  - mem_depolar_prob: Per-step memory depolarization probability; converted internally to T.
  - seed: RNG seed.
- Returns: (sim, net, logging::DataFrame).
"""
function prepare_sim(fig::Figure, n::Int, link_success_prob::Float64, mem_depolar_prob::Float64, seed::Int)
    Random.seed!(seed)

    repr = QuantumOpticsRepr()

    decoherence_rate = -log(1 - mem_depolar_prob)
    noise_model = Depolarization(1 / decoherence_rate)

    logging = DataFrame(Δt = Float64[], fidelity = Float64[])

    switch  = Register([Qubit() for _ in 1:(n+1)], [repr for _ in 1:(n+1)], [noise_model for _ in 1:(n+1)])
    clients = [Register([Qubit()], [repr], [noise_model]) for _ in 1:n]

    graph = star_graph(n + 1)
    net   = RegisterNet(graph, [switch, clients...])
    sim   = get_time_tracker(net)
 
    # Attach the network plot to net and capture its obs
    _, ax_net, _, net_obs = registernetplot_axis(fig[1, 2], net)
    ax_net.title = "Network of n=5 users (live)"
    # Fix the visible ranges
    xlims!(ax_net, -15, 15)
    ylims!(ax_net, -15, 15)
    ax_net.aspect = Makie.DataAspect()  # keep aspect ratio
    Makie.deregister_interaction!(ax_net, :scrollzoom) # disable zoom and pan interactions
    Makie.deregister_interaction!(ax_net, :dragpan)

    @process PiecemakerProt(sim, n, net, link_success_prob, logging, 1, net_obs) # set rounds=1

    return sim, net, logging
end

# A helper to add parameter sliders to visualizations
function add_conf_sliders(fig)
    conf = Dict(
        :link_success_prob => 0.5,
        :mem_depolar_prob => 0.1,
    )
    conf_obs = Observable(conf)
    sg = SliderGrid(
        fig,
        (label = "link success prob",
            range = 0.05:0.05:1.0, format = "{:.2f}", startvalue = conf[:link_success_prob]),
        (label = "mem depolar prob",
            range = 0.05:0.05:1.0, format = "{:.2f}", startvalue = conf[:mem_depolar_prob]),
        width = 300,
    )

    names = [:link_success_prob, :mem_depolar_prob]
    for (name,slider) in zip(names,sg.sliders)
        on(slider.value) do val
            conf_obs[][name] = val
        end
    end
    conf_obs
end

# Serve the Makie app
landing = Bonito.App() do

    fig = Figure(resolution = (800, 600))
    ax_fid = Axis(fig[1, 1], xlabel="Δt (time steps)", ylabel="Fidelity to GHZₙ", title="Fidelity")
    scatter!(ax_fid, fidelity_points, markersize = 8)
    ylims!(ax_fid, 0, 1.05)

    running = Observable{Union{Bool,Nothing}}(false)
    fig[2, 1] = buttongrid = GridLayout(tellwidth = false)
    buttongrid[1,1] = b = Makie.Button(
        fig,
        label = @lift($running ? "Running..." : "Run once"),
        height = 30, tellwidth = false,
    )

    conf_obs = add_conf_sliders(fig[2, 2])

    on(b.clicks) do _
        if running[] # ignore while already running
            return
        end
        running[] = true
        @async begin
            try # run the sim
                sim, net, _ = prepare_sim(fig, 5, conf_obs[][:link_success_prob], conf_obs[][:mem_depolar_prob], 42)
                run(sim)
            finally
                running[] = false
            end
        end
    end

    content = md"""
    Pick simulation settings and hit “Run once”. The left panel plots the running fidelity to the target GHZ state; the right panel shows the network state as it evolves.

    $(fig.scene)

    # GHZ state distribution with a quantum entanglement switch

    This demo simulates a star-shaped network with a central switch node and n client nodes. Each client holds one memory qubit locally and one at the switch. The switch has an extra “piecemaker” qubit (slot n+1) that is initialized in the |+⟩ state; it is used to “stitch together” all successful links into an n-party GHZ state.

    What happens during one run:
    - Per time step, the switch attempts to entangle with each client in parallel (success probability set by the slider “link success prob”).
    - When a client<>switch entanglement attempt succeeds, the switch immediately fuses the client’s switch-side qubit with the piecemaker via a CNOT, measures the client qubit in Z, and sends the outcome to the client. The client applies necessary corrections.
    - After all clients have been fused, the piecemaker is measured in X. The first client receives that outcome and applies a Z correction if needed.
    - The current n-qubit state (the clients’ memory qubits) is compared to the ideal GHZₙ target state. The resulting fidelity is plotted as a point on the left over the number of taken time steps Δt.

    Noise model:
    - Memory qubits are subject to depolarizing noise ([`Depolarization`](https://github.com/QuantumSavory/QuantumSavory.jl/blob/2d40bb77b2abdebdd92a0d32830d97a9234d2fa0/src/backgrounds.jl#L18) background). The slider “mem depolar prob” controls the memory depolarization probability.

    UI guide:
    - Left: fidelity vs simulation time Δt. Points accumulate across runs so you can compare settings.
    - Right: network snapshot. Edges appear when links are established; fusions and measurements trigger visual updates.
    - Sliders: tune link success probability and memory depolarization probability before each run.
    - Button: starts a single run with the current settings.

    NOTE that this is a simplified simulation for demonstration purposes. In particular, it assumes instantaneous gates as well as classical communication. The only time inducing steps are the attempts for heralded entanglement generation (Δt = 1 time step each).

    [Browse or modify the code for this simulation on GitHub.](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/piecemakerswitch/live_visualization_network_interactive.jl)
    """
    return Bonito.DOM.div(Bonito.MarkdownCSS, Bonito.Styling, custom_css, content)
end;


isdefined(Main, :server) && close(server);
port = parse(Int, get(ENV, "QS_GHZSWITCH_PORT", "3000"))
interface = get(ENV, "QS_GHZSWITCH_IP", "0.0.0.0")  # Bind to all interfaces
proxy_url = get(ENV, "QS_GHZSWITCH_PROXY", "")
server = Bonito.Server(interface, port; proxy_url);
Bonito.HTTPServer.start(server)
Bonito.route!(server, "/" => landing);


@info "app server is running on http://$(interface):$(port) | proxy_url=`$(proxy_url)`"

wait(server)