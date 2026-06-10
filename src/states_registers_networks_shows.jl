function Base.show(io::IO, s::StateRef)
    if get(io, :compact, false) | haskey(io, :typeinfo)
        print(io, "State $(typeof(s.state[]).name.module) of size $(nsubsystems(s.state[]))")
    else
        print(io, "State containing $(nsubsystems(s.state[])) subsystems in $(typeof(s.state[]).name.module) implementation")
        print(io, "\n  In registers:")
        for (i,r) in zip(s.registerindices, s.registers)
            if isnothing(r)
                print(io, "\n    not used")
            else
                print(IOContext(io, :compact => true), "\n    ",(r[i]))
            end
        end
    end
end

function Base.show(io::IO, r::Register)
    regname = namestr(r; useobjectid=false)
    if get(io, :compact, false) | haskey(io, :typeinfo)
        print(io, "Register $(regname)")
    else
        print(io, "Register $(regname) with $(length(r.traits)) slots") # TODO make this length call prettier
        print(io, ": [ ")
        print(io, join(string.(typeof.(r.traits)), " | "))
        print(io, " ]")
        print(io, "\n  Slots:")
        for (i,s) in zip(r.stateindices, r.staterefs)
            if isnothing(s)
                print(io, "\n    nothing")
            else
                print(io, "\n    Subsystem $(i) of $(typeof(s.state[]).name.module).$(typeof(s.state[]).name.name) $(objectid(s.state[]))")
            end
        end
    end
end

function Base.show(io::IO, net::RegisterNet)
    print(io, "A network of $(length(net.registers)) registers in a graph of $(length(edges(net.graph))) edges\n")
end

function Base.show(io::IO, r::RegRef)
    regstr = namestr(parent(r))
    if get(io, :compact, false) | haskey(io, :typeinfo)
        print(io, "$(regstr).$(r.idx)")
    else
        print(io, "Slot $(r.idx)/$(length(r.reg.traits)) of Register $(regstr)") # TODO make this length call prettier
        print(io, "\nContent:")
        i,s = r.reg.stateindices[r.idx], r.reg.staterefs[r.idx]
        if isnothing(s)
            print(io, "\n    nothing")
        else
            print(io, "\n    $(i) @ ")
            print(IOContext(io, :compact => true), s)
        end
    end
end

"""The human-readable name or the simulated object as a string or `nothing`."""
function name end
name(r::Register) = isnothing(r.netparent[]) ? nothing : get(r.netparent[].names, r.netindex[], nothing)
name(r::RegisterNet) = r.name
name(::Nothing) = nothing
"""The human-readable name or the simulated object as a string (potentially empty)."""
function namestr(n)
    return isnothing(name(n)) ? "" : name(n)
end
function namestr(reg::Register; useobjectid=true)
    net = parent(reg)
    if isnothing(net)
        useobjectid ? "$(objectid(reg))" : ""
    else
        regname = name(reg)
        if isnothing(regname)
            netname = name(net)
            if isnothing(netname)
                "$(parentindex(reg))"
            else
                "$netname[$(parentindex(reg))]"
            end
        else
            "$regname(#$(parentindex(reg)))"
        end
    end
end

function Base.show(io::IO, m::MIME"text/html", r::RegRef)
    print(io,"""
    <div class="quantumsavory_show quantumsavory_regref">
    """)
    isnothing(r.reg.netparent[]) || print(io,"""
    <span class="quantumsavory_regref_netname">$(namestr(r.reg.netparent[]))</span>
    <span class="quantumsavory_regref_regindex">$(r.reg.netindex[])</span>
    <span class="quantumsavory_regref_name">$(namestr(r.reg))</span>
    """)
    print(io,"""
    <span class="quantumsavory_regref_slotindex">$(r.idx)</span>
    </div>
    """)
end

function Base.show(io::IO, m::MIME"text/html", s::StateRef)
    print(io,"""
    <div class="quantumsavory_show quantumsavory_stateref">
    <div class="quantumsavory_stateref_regrefs">
    <ol>
    """)
    for rr in slots(s)
        print(io, "<li>")
        show(io, m, rr)
        print(io, "</li>")
    end
    print(io,"""
    </ol>
    </div>
    <div class="quantumsavory_stateref_state">
    """)
    stateshow(io, m, quantumstate(s), s)
    print(io,"""
    </div>
    </div>
    """)
end

using QuantumOptics
get_statedata(state::Ket) = state.data
get_statedata(state::Bra) = state.data
get_statedata(state::Operator) = state.data
get_statedata(state::LazyKet) = get_statedata(Ket(state))
get_statedata(state) = nothing

function state_to_blochcoord(state::AbstractOperator)
    b = basis(state)

    x = real(tr(state * sigmax(b)))
    y = real(tr(state * sigmay(b)))
    z = real(tr(state * sigmaz(b)))

    θ = acos(clamp(z, -1, 1))
    ϕ = atan(y, x)

    return (x, y, z), (θ, ϕ)
end
state_to_blochcoord(state::StateVector) = state_to_blochcoord(dm(state))

format_complex(z) = @sprintf("%.3f%+.3fi", real(z), imag(z))
function html_statedata(state::Ket)
    α, β = state.data
    α = @sprintf("%.3f%+.3fi", real(α), imag(α))
    β = @sprintf("%.3f%+.3fi", real(β), imag(β))

    """
    <div class="quantumsavory_state">
        <span class="quantumsavory_coeff">$α</span>
        <span class="quantumsavory_basis0">|0⟩</span>
        +
        <span class="quantumsavory_coeff">$β</span>
        <span class="quantumsavory_basis1">|1⟩</span>
    </div>
    """
end
function html_statedata(state::Bra)
    α, β = state.data
    α = format_complex(α)
    β = format_complex(β)

    """
    <div class="quantumsavory_state">
        <span class="quantumsavory_basis0">⟨0|</span>
        <span class="quantumsavory_coeff">$α</span>
        +
        <span class="quantumsavory_basis1">⟨1|</span>
        <span class="quantumsavory_coeff">$β</span>
    </div>
    """
end
function html_statedata(state::Operator)
    α, β, γ, δ = state.data

    α = format_complex(α)
    β = format_complex(β)
    γ = format_complex(γ)
    δ = format_complex(δ)

    """
    <table class="quantumsavory_densitymatrix">
        <tr>
            <td>$α</td>
            <td>$β</td>
        </tr>
        <tr>
            <td>$γ</td>
            <td>$δ</td>
        </tr>
    </table>
    """
end
html_statedata(state::LazyKet) = html_statedata(Ket(state))
html_statedata(state) = ""

"""Similar to `show(io, ::MIME"", ...)`, but private to avoid piracy."""
function stateshow(io, ::MIME"text/html", state, stateref)
    α, β = get_statedata(state)
    (x, y, z), (θ, ϕ) = state_to_blochcoord(state)
    r = sqrt(x^2 + y^2 + z^2)

    xlog2x(x) = iszero(x) ? 0.0 : x * log2(x)

    print(io, """
<style>
    .quantumsavory_qubit {
        font-family: "STIX Two Text", "Cambria Math", "Latin Modern Roman", serif;
        min-width: 250px;
        max-width: 400px;
        line-height: 1.35;
        color: #222;
    }
    .quantumsavory_section {
        margin-top: 1em;
    }
    .quantumsavory_heading {
        font-size: 1.05em;
        font-weight: 700;
        margin-bottom: 0.35em;
        border-bottom: 1px solid #ddd;
        padding-bottom: 0.15em;
    }

    .quantumsavory_state {
        text-align: center;
        font-size: 1.15em;
        margin: 0.8em 0;
    }
    .quantumsavory_coeff {
        font-family: "JuliaMono", monospace;
        color: #444;
    }
    .quantumsavory_basis0 {
        color: #2b6cb0;
        font-weight: 600;
    }
    .quantumsavory_basis1 {
        color: #c53030;
        font-weight: 600;
    }
    .quantumsavory_meta {
        margin-top: 0.5em;
        text-align: center;
    }
    .quantumsavory_typename {
        font-family: "JuliaMono", monospace;
    }

    .quantumsavory_grid {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 1em;
    }
    .quantumsavory_table {
        width: 100%;
        border-collapse: collapse;
    }
    .quantumsavory_table td {
        padding: 0.15em 0.4em;
    }
    .quantumsavory_table td:first-child {
        font-weight: 600;
    }

    .quantumsavory_x { color: #d53f3f; }
    .quantumsavory_y { color: #38a169; }
    .quantumsavory_z { color: #3182ce; }
    .quantumsavory_theta { color: #276749; }
    .quantumsavory_phi   { color: #2c5282; }
    .quantumsavory_r     { color: #6b46c1; }

    .quantumsavory_densitymatrix {
        margin: 0.8em auto;
        border-collapse: collapse;
        font-family: "JuliaMono", monospace;
    }
    .quantumsavory_densitymatrix td {
        border: 1px solid #ddd;
        padding: 0.25em 0.5em;
        text-align: center;
    }
    .quantumsavory_properties {
        text-align: center;
    }
</style>

<div class="quantumsavory_qubit">
    <div class="quantumsavory_section">
        <div class="quantumsavory_heading">Quantum State</div>
            $(html_statedata(state))

            <div class="quantumsavory_meta">
                Type:
                <span class="quantumsavory_typename">$(nameof(typeof(state)))</span>
                <br>
                Basis: $(basis(state))
            </div>
        </div>

    <div class="quantumsavory_section">
        <div class="quantumsavory_heading">Bloch Coordinates</div>

        <div class="quantumsavory_grid">
            <table class="quantumsavory_table">
                <tr><td class="quantumsavory_x">⟨X⟩</td><td>$(@sprintf("% .3f", x))</td></tr>
                <tr><td class="quantumsavory_y">⟨Y⟩</td><td>$(@sprintf("% .3f", y))</td></tr>
                <tr><td class="quantumsavory_z">⟨Z⟩</td><td>$(@sprintf("% .3f", z))</td></tr>
            </table>

            <table class="quantumsavory_table">
                <tr><td class="quantumsavory_theta">θ</td><td>$(@sprintf("%.1f", rad2deg(θ)))°</td></tr>
                <tr><td class="quantumsavory_phi">ϕ</td><td>$(@sprintf("%.1f", rad2deg(ϕ)))°</td></tr>
                <tr><td class="quantumsavory_r">|r|</td><td>$(@sprintf("%.3f", r))</td></tr>
            </table>
        </div>
    </div>

    <div class="quantumsavory_section">
        <div class="quantumsavory_heading">State Properties</div>
        <div class="quantumsavory_properties">
            Purity: <b>$(@sprintf("%.3f", (1+r^2)/2))</b>
            <br>
            Entropy: <b>$(@sprintf("%.3f", -xlog2x((1+r)/2) - xlog2x((1-r)/2)))</b>
        </div>
    </div>
</div>
""")
end
