Use `registernetplot_axis` for the register/network view.

The documented pattern is:

```julia
fig = Figure(size=(800, 400))
_, ax, plt, obs = registernetplot_axis(fig[1, 1], net)
```

That gives you:

- the plotted registers and occupied slots;
- interactive inspection by hovering or clicking;
- and an observable-like handle `obs` for updates.

To force-show metadata for a slot, use:

```julia
QuantumSavory.showmetadata(fig, ax, plt, 2, 3)
```

That panel can include tag metadata as well as state information.

To update the visualization during a running simulation, change the state and
then notify the returned observable instead of rebuilding the plot:

```julia
run(sim, t)
notify(obs)
```

If you also want to inspect locks or graph metadata rather than only register
state, use `resourceplot_axis`.

Other useful details from the docs:

- the plotting helpers are built on Makie;
- `registercoords` can place registers on custom layouts or maps;
- protocol-specific visualizations also exist for some `ProtocolZoo` objects.

See `docs/src/visualizations.md` and the visualization examples under
`examples/`.

