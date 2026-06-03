function Base.show(io::IO, m::MIME"image/png", s::StateRef)
    f = Figure()
    stateshowimage(f,QuantumSavory.quantumstate(s),s)
    show(io, m, f)
end

"""Similar to `show(io, ::MIME"", ...)`, but private to avoid piracy. Instead of an IO instance, it takes a Makie axis."""
function stateshowimage(subfig, state, stateref)
    a = Axis(subfig[1,1])
    hidedecorations!(a)
    hidespines!(a)
    text = "state of type\n$(typeof(state))\ndoes not support rich visualization"
    text!(a,0,0;text,align=(:center,:center))
end

function stateshowimage(subfig, state::AbstractOperator, stateref)
    if nsubsystems(state) == 1
        draw_bloch!(subfig[1,1], state)
        draw_stateinfo!(subfig[1,2], state)
    elseif nsubsystems(state) == 2
    else
        ax = Axis(subfig[1,1])
        hidedecorations!(ax)
        hidespines!(ax)
        text = "state of type\n$(typeof(state))\nwith $(nsubsystems(state)) subsystems\ndoes not support rich visualization"
        text!(ax,0,0;text,align=(:center,:center))
    end
end
stateshowimage(subfig, state::StateVector, stateref) = stateshowimage(subfig, dm(state), stateref)

function stateshowimage(subfig, state::QuantumClifford.MixedDestabilizer, stateref)
    stab = QuantumClifford.stabilizerview(state)
    names = [
        QuantumSavory.namestr(s.reg,useobjectid=false)*".$(s.idx)"
        for s in QuantumSavory.slots(stateref)
        ]
    subfig,ax,p = QuantumClifford.stabilizerplot_axis(subfig, stab)
    #ax.xticksvisible = true
    ax.xticklabelsvisible = true
    ax.xticks = (1:length(names), names)
    ax.xticklabelrotation = pi/2*0.8
    ax.yticks = (Int[], String[])
    subfig
end


function draw_bloch!(subfig, state)
    ax = Axis3(subfig, aspect=:data, azimuth=deg2rad(30), elevation=deg2rad(30))
    hidedecorations!(ax)
    hidespines!(ax)

    # draw bloch sphere
    mesh!(ax, Sphere(Point3f(0), 1.0f0); color="#FFDDDD", alpha=0.2, transparency=true, shading=NoShading, rasterize=3)

    # draw axes
    lines!(ax, [Point3f(1.0, 0, 0), Point3f(-1.0, 0, 0)]; color="gray") # X-axis
    lines!(ax, [Point3f(0, 1.0, 0), Point3f(0, -1.0, 0)]; color="gray") # Y-axis
    lines!(ax, [Point3f(0, 0, 1.0), Point3f(0, 0, -1.0)]; color="gray") # Z-axis

    # draw XY and XZ
    φ = range(0, 2π, length = 100)
    lines!(ax, [Point3f(cos(φi), sin(φi), 0) for φi in φ]; color="gray", linewidth=1.0) # XY
    lines!(ax, [Point3f(cos(φi), 0, sin(φi)) for φi in φ]; color="gray", linewidth=1.0) # XZ

    # draw longitudes
    φ_curve = range(0, 2π, 600)
    θ_vals = [1, 2, 3] * π / 4
    for θi in θ_vals
        x_line = sin.(φ_curve) .* cos(θi)
        y_line = sin.(φ_curve) .* sin(θi)
        z_line = cos.(φ_curve)
        lines!(ax, x_line, y_line, z_line; color="gray", alpha=0.2, linewidth=1.0)
    end

    # draw latitudes
    φ_vals = [1, 3] * π / 4
    θ_curve = range(0, 2π, 600)
    for ϕ in φ_vals
        x_ring = sin(ϕ) .* cos.(θ_curve)
        y_ring = sin(ϕ) .* sin.(θ_curve)
        z_ring = fill(cos(ϕ), length(θ_curve))
        lines!(ax, x_ring, y_ring, z_ring; color="gray", alpha=0.2, linewidth=1.0)
    end

    # draw labels
    text!(ax, L"|0\rangle", position = Point3f(0, 0, 1.2), fontsize=20, align=(:center,:center))
    text!(ax, L"|1\rangle", position = Point3f(0, 0, -1.2), fontsize=20, align=(:center,:center))
    text!(ax, L"x", position = Point3f(1.2, 0, 0), fontsize=20, align=(:center,:center))
    text!(ax, L"y", position = Point3f(0, 1.2, 0), fontsize=20, align=(:center,:center))

    # draw state vector
    b = basis(state)
    x = tr(state * sigmax(b))
    y = tr(state * sigmay(b))
    z = tr(state * sigmaz(b))
    arrows3d!(ax, Point3f(0), Point3f(x, y, z); color=:red, shaftradius = 0.02, tiplength = 0.08, tipradius = 0.05)
    lines!(ax, [Point3f(x, y, 0), Point3f(x, y, z)], linestyle=:dash, color=:gray)
    lines!(ax, [Point3f(0), Point3f(x, y, 0)], linestyle=:dash, color=:gray)
    scatter!(ax, [Point3f(x, y, 0)]; markersize=5, color=:gray)
end