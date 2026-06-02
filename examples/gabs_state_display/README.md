# Gabs Gaussian state display demo

Shows terminal text, HTML tables, and optional PNG plots for `GabsRepr` register states.

```julia
# text + HTML
julia --project=. examples/gabs_state_display/demo.jl

# + PNG heatmaps (plotting env includes Gabs + CairoMakie)
julia --project=test/projects/plotting -e 'using Pkg; Pkg.instantiate()'
julia --project=test/projects/plotting examples/gabs_state_display/demo.jl
```

Outputs land in `examples/gabs_state_display/output/` (`*.html`, `*.png`).
