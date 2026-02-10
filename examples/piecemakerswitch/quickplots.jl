using GLMakie

p = range(0,1, length=100)

fig = Figure()
ax = Axis(fig[1, 1], xlabel="p", ylabel="E[X]")
lines!(ax, p, 1 ./p, label="1/p")
lines!(ax, p, 1 ./p .+ 1 ./(p .- 2), label="1/p + 1/(p-2)")
lines!(ax, p, (2 .- p) ./ p, label="(2-p) / p")
axislegend(ax)
display(fig)