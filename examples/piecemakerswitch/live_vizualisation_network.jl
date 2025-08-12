# run_with_live_plot_and_registernetplot.jl

using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumClifford: ghz
using Graphs
using ConcurrentSim
using ResumableFunctions
using DataFrames
using Random

using GLMakie
GLMakie.activate!()  # OpenGL window

const fidelity_points = Observable(Point2f[])

const ghzs = [ghz(n) for n in 1:7]  # precompute GHZ targets

function fusion(piecemaker_slot, client_slot)
    apply!((piecemaker_slot, client_slot), CNOT)
    res = project_traceout!(client_slot, σᶻ)
    return res
end

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

        sleep(0.5)
        notify(net_obs)  # show post-measurement state
        sleep(0.5)

        # live update
        push!(fidelity_points[], Point2f(t, fidelity))
        notify(fidelity_points)
    end
end

# NOTE: we’ll pass the `obs` from registernetplot_axis into the protocol so we can call notify(obs)
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
                    #notify(net_obs)  # refresh view
                end

                while true
                    counterpart = querydelete!(net[1], EntanglementCounterpart, ❓, ❓)
                    if !isnothing(counterpart)
                        slot, _, _ = counterpart
                        i = slot.idx  # client index (1..n)

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
                        # The plot reflects current net state; just notify to refresh.
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

        # cleanup qubits (plot will update on next round’s actions)
        foreach(q -> (traceout!(q); unlock(q)), net[1])
        foreach(q -> (traceout!(q); unlock(q)), [net[1 + i][1] for i in 1:n])
        notify(net_obs)

        rounds -= 1
        @debug "Round $(rounds) finished"
    end
    # between rounds (real time pause so it’s watchable)
    sleep(0.7)
    fidelity_points[] = Point2f[]  # clear points for next round
    notify(fidelity_points)
end

function prepare_sim(n::Int, repr::AbstractRepresentation, noise::Union{AbstractBackground,Nothing},
    p_link::Float64, seed::Int, logging::DataFrame, rounds::Int)

    Random.seed!(seed)

    switch  = Register([Qubit() for _ in 1:(n+1)], [repr for _ in 1:(n+1)], [noise for _ in 1:(n+1)])
    clients = [Register([Qubit()], [repr], [noise]) for _ in 1:n]

    graph = star_graph(n + 1)
    net   = RegisterNet(graph, [switch, clients...])
    sim   = get_time_tracker(net)

    # create a temporary figure slot to hold obs after we have net
    fig = Figure(resolution = (1200, 520))
    ax_fid = Axis(fig[1, 1], xlabel="Δt (simulation time)", ylabel="Fidelity to GHZₙ", title="Fidelity (live)")
    scatter!(ax_fid, fidelity_points, markersize=8); ylims!(ax_fid, 0, 1)
 
    # Now attach the network plot to net and capture its obs
    _, ax_net, _, net_obs = registernetplot_axis(fig[1, 2], net)

    @process PiecemakerProt(sim, n, net, p_link, logging, rounds, net_obs)

    ax_net.title = "Network (live)"
    display(fig)
    return sim
end

function main(; n = 5, link_success_prob = 0.5, rounds = 5, seed = 42)
    # noise
    mem_depolar_prob = 0.5
    decoherence_rate = -log(1 - mem_depolar_prob)
    noise_model = Depolarization(1 / decoherence_rate)

    logging = DataFrame(Δt = Float64[], fidelity = Float64[])

    sim = prepare_sim(n, QuantumOpticsRepr(), noise_model, link_success_prob, seed, logging, rounds)
    
    # Run in background so UI can repaint
    simtask = @async begin
        t = @elapsed run(sim)
        @info "Simulation finished in $(t) seconds"
    end
    wait(simtask)

    if !Base.isinteractive()
        @info "Press Enter to close the window…"
        readline()
    end
end

main()