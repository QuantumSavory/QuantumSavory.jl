# [Visualizations](@id Visualizations)

```@meta
DocTestSetup = quote
    using QuantumSavory
end
```

The [`registernetplot_axis`](@ref) function can be used to draw a given set of registers, together with the quantum states they contain. It also provides interactive tools for inspecting the content of various registers.

The [`resourceplot_axis`](@ref) function can be used to draw all locks and resources stored in a meta-graph governing a discrete event simulation.