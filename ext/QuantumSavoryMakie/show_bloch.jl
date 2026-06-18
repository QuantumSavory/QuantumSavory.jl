using QuantumSavory: blochparams

function draw1q_bloch!(subfig, state::Union{AbstractOperator, StateVector})
    nsubsystems(state) != 1 && error("Bloch sphere visualization is only supported for single-qubit states.")

    ax = Axis3(subfig, aspect=:data, azimuth=deg2rad(30), elevation=deg2rad(30), protrusions=(0,0,0,0), limits=(-1.2, 1.2, -1.2, 1.2, -1.2, 1.2))
    tightlimits!(ax)
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

    (x, y, z), (θ, ϕ) = blochparams(state)
    # draw state vector
    arrows3d!(ax, Point3f(0), Point3f(x, y, z); color=:red, shaftradius=0.01, tiplength=0.08, tipradius=0.05)
    lines!(ax, [Point3f(x, y, 0), Point3f(x, y, z)], linestyle=:dash, color=:gray, alpha=0.5)
    lines!(ax, [Point3f(0), Point3f(x, y, 0)], linestyle=:dash, color=:gray, alpha=0.5)
    scatter!(ax, [Point3f(x, y, 0)]; markersize=5, color=:red, alpha=0.5)
    # draw angles θ and ϕ
    ϕ_arc = range(0, atan(y,x), length=50)
    lines!(ax, 0.2.*cos.(ϕ_arc), 0.2.*sin.(ϕ_arc), zeros(length(ϕ_arc)); color=:blue, alpha=0.5)
    φ = atan(y, x)
    θcurve = range(0, acos(clamp(z, -1, 1)), length=50)
    lines!(ax, 0.2.*sin.(θcurve).*cos(φ), 0.2.*sin.(θcurve).*sin(φ), 0.2.*cos.(θcurve); color=:green, alpha=0.5)
end

function _draw1q_statedata!(ax, state::Ket)
    α, β = state.data
    α = @sprintf("%.3f%+.3fi", real(α), imag(α))
    β = @sprintf("%.3f%+.3fi", real(β), imag(β))
    text!(ax, 0.77, 0.43; text=L"(%$α)|0\rangle", align=(:center, :center))
    text!(ax, 0.77, 0.39; text=L"(%$β)|1\rangle", align=(:center, :center))
end
function _draw1q_statedata!(ax, state::Bra)
    α, β = state.data
    α = @sprintf("%.3f%+.3fi", real(α), imag(α))
    β = @sprintf("%.3f%+.3fi", real(β), imag(β))
    text!(ax, 0.77, 0.43; text=L"\langle 0|(%$α)", align=(:center, :center))
    text!(ax, 0.77, 0.39; text=L"\langle 1|(%$β)", align=(:center, :center))
end
function _draw1q_statedata!(ax, state::Operator)
    α, β, γ, δ = state.data
    α = @sprintf("%.3f%+.3fi", real(α), imag(α))
    β = @sprintf("%.3f%+.3fi", real(β), imag(β))
    γ = @sprintf("%.3f%+.3fi", real(γ), imag(γ))
    δ = @sprintf("%.3f%+.3fi", real(δ), imag(δ))
    text!(ax, 0.77, 0.43; text=L"%$α \quad %$β", align=(:center, :center))
    text!(ax, 0.77, 0.38; text=L"%$γ \quad %$δ", align=(:center, :center))
    text!(ax, 0.60, 0.41; text="[", align=(:center, :center), fontsize=40, color=:gray)
    text!(ax, 0.94, 0.41; text="]", align=(:center, :center), fontsize=40, color=:gray)
end
_draw1q_statedata!(state::LazyKet) = _draw1q_statedata!(Ket(state))
_draw1q_statedata!(state) = nothing

function draw1q_stateinfo!(subfig, state::Union{AbstractOperator, StateVector})
    ax = Axis(subfig)
    hidedecorations!(ax)
    hidespines!(ax)
    xlims!(ax, 0, 1)
    ylims!(ax, 0, 1)

    (x, y, z), (θ, ϕ) = blochparams(state)
    r = sqrt(x^2 + y^2 + z^2)

    # Bloch coordinates
    text!(
        ax, 0.77, 0.85;
        text = rich("Bloch Coordinates", font=:bold),
        align = (:center, :center)
    )
    text!(
        ax, 0.62, 0.81;
        text = rich(
            rich("⟨X⟩", color=:red),   " = $(@sprintf("% .3f", x))\n",
            rich("⟨Y⟩", color=:green), " = $(@sprintf("% .3f", y))\n",
            rich("⟨Z⟩", color=:blue),  " = $(@sprintf("% .3f", z))",
        ),
        align = (:left, :top)
    )
    text!(
        ax, 0.80, 0.81;
        text = rich(
            rich("θ", color=:darkgreen), " = $(@sprintf("% .1f", rad2deg(θ)))°\n",
            rich("φ", color=:darkblue),  " = $(@sprintf("% .1f", rad2deg(ϕ)))°\n",
            rich("|r|", color=:purple),  " = $(@sprintf("%.3f", r))",
        ),
        align = (:left, :top)
    )

    # Quantum state data
    text!(
        ax, 0.77, 0.61;
        text = rich(
            rich("Quantum State\n", font=:bold),
            "Type: $(nameof(typeof(state)))\n",
            "Basis: $(basis(state))"
        ),
        align = (:center, :top)
    )
    _draw1q_statedata!(ax, state)

    # State properties
    xlog2x(x) = iszero(x) ? 0.0 : x * log2(x)
    text!(
        ax, 0.77, 0.23;
        text=rich(rich("State Properties\n", font=:bold),
            "Purity: $(@sprintf("%.3f", (1+r^2)/2))\n",
            "Entropy: $(@sprintf("%.3f", -xlog2x((1+r)/2) - xlog2x((1-r)/2)))",
        ),
        align=(:center, :center)
    )
end