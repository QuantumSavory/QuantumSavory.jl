using QuantumSavory
using QuantumSavory.ProtocolZoo
using ConcurrentSim
using ResumableFunctions

using Graphs
using GLMakie
GLMakie.activate!()

using NetworkLayout
using Random

adjm = [0 1 0 0 1 0 0 0
        1 0 1 0 0 0 0 0
        0 1 0 1 0 1 0 0
        0 0 1 0 0 0 1 1
        1 0 0 0 0 1 0 1
        0 0 1 0 1 0 1 0
        0 0 0 1 0 1 0 1
        0 0 0 1 1 0 1 0]
graph = SimpleGraph(adjm)

regsize = 20
net = RegisterNet(graph, [Register(regsize, T1Decay(10.0)) for i in 1:8])
sim = get_time_tracker(net)

using GraphPlot
nodelabel = ["Alice", 2, 3, 4, 5, 6, 7, "Bob"]
layout=(args...)->spring_layout(args...; C=20)

function prepare_vis(consumer::EntanglementConsumer, params=nothing)
    ###
    fig = Figure(;size=(1200, 1100))

    # the network part of the visualization
    layout = SquareGrid(cols=:auto, dx=30.0, dy=-30.0)(graph) # provided by NetworkLayout, meant to simplify plotting of graphs in 2D
    _, ax, _, obs = registernetplot_axis(fig[1:2,1], net; registercoords=layout)

    # the performance log part of the visualization
    entlog = Observable(consumer.log) # Observables are used by Makie to update the visualization in real-time in an automated reactive way
    ts = @lift [e[1] for e in $entlog]  # TODO this needs a better interface, something less cluncky, maybe also a whole Makie recipe
    tzzs = @lift [Point2f(e[1],e[2]) for e in $entlog]
    txxs = @lift [Point2f(e[1],e[3]) for e in $entlog]
    Δts = @lift length($ts)>1 ? $ts[2:end] .- $ts[1:end-1] : [0.0]
    entlogaxis = Axis(fig[1,2], xlabel="Time", ylabel="Entanglement", title="Entanglement Successes")
    ylims!(entlogaxis, (-1.04,1.04))
    stem!(entlogaxis, txxs)
    histaxis = Axis(fig[2,2], xlabel="ΔTime", title="Histogram of Time to Successes")
    hist!(histaxis, Δts)

    avg_fids = @lift cumsum([e[3] for e in $entlog])./cumsum(ones(length($entlog))) #avg fidelity per unit time
    fid_info = @lift [Point2f(t,f) for (t,f) in zip($ts, $avg_fids)]
    fid_axis = Axis(fig[3,1], xlabel="Time", ylabel="Avg. Fidelity", title="Time evolution of Average Fidelity")
    lines!(fid_axis, fid_info)

    num_epr = @lift cumsum(ones(length($entlog)))./($ts) #avg number of pairs per unit time
    num_epr_info = @lift [Point2f(t,n) for (t,n) in zip($ts, $num_epr)]
    num_epr_axis = Axis(fig[3,2], xlabel="Time", title="Avg. Number of Entangled Pairs between Alice and Bob")
    lines!(num_epr_axis, num_epr_info)

    if !isnothing(params)
        #  sliders
        sg = SliderGrid(
        fig[4,1],
        (label="Probability of success of Entanglement generation at each attempt",
            range=0.001:0.05:1.0, format="{:.3f}", startvalue=0.001),
        (label="Local busy time for swapper",
            range=0.001:0.5:10.0, format="{:.3f}", startvalue=0.001),
        (label="Wait time after failure to lock qubits for a swap",
            range=0.1:0.05:1.0, format="{:.2f}", startvalue=0.1),
        (label="Period of time between subsequent queries at the consumer",
            range=0.001:0.05:1.0, format="{:.3f}", startvalue=0.001),
        (label="Period of time between subsequent queries at the DecoherenceProtocol",
            range=0.001:0.05:1.0, format="{:.3f}", startvalue=0.001),

        width = 600,
        tellheight = true)

        for (param, slider) in zip(params, sg.sliders)
            on(slider.value) do val
                param[] = val
            end
        end
    end


    # display(fig)

    return consumer.sim, consumer.net, obs, entlog, entlogaxis, fid_axis, histaxis, num_epr_axis, fig
end