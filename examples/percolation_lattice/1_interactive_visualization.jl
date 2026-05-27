using GLMakie

include("interactive_dashboard.jl")

fig = build_dashboard()
display(fig)
