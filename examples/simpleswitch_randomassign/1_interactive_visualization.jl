using GLMakie

include("setup.jl")

# Prepare all of the simulation components (while all visualization components are prepared in the rest of this file)
n, sim, net, switch_protocol, client_pairs, client_unordered_pairs, consumers, rates, rate_scale = prepare_simulation()

# Prepare the main figure
fig = Figure(size=(1600,800))
fig_plots = fig[1,1]

# Subfigure for the network visualization
_,ax,_,obs = registernetplot_axis(fig_plots[1:2,1],net)

# Subfigure for the "backlog over time"
backlog = Observable(Float64[0])
sim_time = Observable(Float64[0])
ax_backlog = Axis(fig_plots[1:2,2], xlabel="time", ylabel="average backlog")
stairs!(ax_backlog,sim_time,backlog)

# Subfigure for the "total successfully established and consumed Bell pairs for a pair of clients"
consumed = Observable(zeros(length(consumers)))
ax_consumed_ticks = ["$i-$j" for (i,j) in client_unordered_pairs]
ax_consumed = Axis(fig_plots[1,3], xlabel="pair", ylabel="consumed pairs", xticks=(1:length(consumers),ax_consumed_ticks))
barplot!(ax_consumed,1:length(consumers),consumed, color=Cycled(2))

# Subfigure for the "backlog for a given pair of clients"
backlog_perpair = Observable(zeros(length(consumers)))
ax_backlog_perpair = Axis(fig_plots[2,3], xlabel="pair", ylabel="backlog", xticks=(1:length(consumers),ax_consumed_ticks))
barplot!(ax_backlog_perpair,1:length(consumers),backlog_perpair)

# Sliders with which to control the request rates
sliderfig_ = fig[2,1]
sliderfig = sliderfig_[2,1]
sliders = []
for ((i,j), rate) in zip(client_pairs, rates)
    slider = Slider(sliderfig[i,j], range=0.05:0.05:2, startvalue=1)
    push!(sliders, slider)
    on(slider.value) do val
        rate[] = val*rate_scale
    end
end
for i in 1:n
    Label(sliderfig[1,i+1], "$(i+1)→", tellwidth=false)
    Label(sliderfig[i+1,1], "→$(i+1)", tellwidth=true)
end
sliderfig_override = sliderfig_[3,1]
slider_override = Slider(sliderfig_override[1,2], range=0.05:0.05:2, startvalue=1)
on(slider_override.value) do val
    for slider in sliders
        @async begin
            set_close_to!(slider, val)
        end
    end
end
Label(sliderfig_override[1,1], "global rate override:")
Label(sliderfig_[1,1], rich("Request Rate Controls:",fontsize=20), tellwidth=false)

# Display the figure...
# display(fig)

# ... and run the simulation while updating plots as needed
step_ts = range(0, 1, step=0.1)
for t in step_ts
    run(sim, t)
    ax.title = "t=$(t)"
    push!(sim_time[],t)
    push!(backlog[], sum(switch_protocol.backlog)/(n-1)/(n-2)/2)
    for (i, consumer) in enumerate(consumers)
        consumed[][i] = length(consumer.log)
    end
    for (l,(i, j)) in enumerate(client_unordered_pairs)
        backlog_perpair[][l] = switch_protocol.backlog[i-1,j-1]
    end
    notify(backlog)
    notify(consumed)
    notify(backlog_perpair)
    notify(obs)
    autolimits!(ax_backlog)
    autolimits!(ax_consumed)
    autolimits!(ax_backlog_perpair)
end