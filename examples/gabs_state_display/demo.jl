using QuantumSavory
using Gabs

const HAS_CAIRO_MAKIE = try
    using CairoMakie
    CairoMakie.activate!()
    true
catch
    false
end

const GABS_REPR = GabsRepr(QuadBlockBasis)
const OUTDIR = joinpath(@__DIR__, "output")

function write_html(path, stateref)
    open(path, "w") do io
        show(io, MIME"text/html"(), stateref)
    end
end

function write_png(path, stateref)
    io = IOBuffer()
    show(io, MIME"image/png"(), stateref)
    write(path, take!(io))
end

"""
Demonstrate rich display of `Gabs` Gaussian states stored in QuantumSavory registers.

Writes HTML (and PNG when CairoMakie is loaded) under `examples/gabs_state_display/output/`.
See `README.md` for project environments to use.
"""
function main()
    mkpath(OUTDIR)

    reg1 = Register([Qumode()], [GABS_REPR])
    initialize!(reg1[1], CoherentState(0.5 + 0.2im))
    sref1 = QuantumSavory.stateof(reg1[1])

    reg2 = Register(fill(Qumode(), 2), fill(GABS_REPR, 2))
    initialize!(reg2[1:2], TwoSqueezedState(0.45))
    sref2 = QuantumSavory.stateof(reg2[1])

    println("One-mode coherent state:")
    show(stdout, sref1)
    println("\n\nTwo-mode squeezed state:")
    show(stdout, sref2)
    println()

    write_html(joinpath(OUTDIR, "one_mode.html"), sref1)
    write_html(joinpath(OUTDIR, "two_mode.html"), sref2)
    println("Wrote HTML to ", OUTDIR)

    if HAS_CAIRO_MAKIE
        write_png(joinpath(OUTDIR, "one_mode.png"), sref1)
        write_png(joinpath(OUTDIR, "two_mode.png"), sref2)
        println("Wrote PNG to ", OUTDIR)
    else
        @warn "CairoMakie not available; run with `--project=test/projects/plotting` for PNG output"
    end
end

main()
