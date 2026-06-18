using QuantumOptics: Ket, Bra, Operator

function Base.show(io::IO, s::StateRef)
    if get(io, :compact, false) | haskey(io, :typeinfo)
        print(io, "State $(nameof(typeof(s.state[]))) of size $(nsubsystems(s.state[]))")
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

# function Base.show(io::IO, m::MIME"text/html", r::RegRef)
#     print(io,"""
#     <div class="quantumsavory_show quantumsavory_regref">
#     """)
#     isnothing(r.reg.netparent[]) || print(io,"""
#     <span class="quantumsavory_regref_netname">$(namestr(r.reg.netparent[]))</span>
#     <span class="quantumsavory_regref_regindex">$(r.reg.netindex[])</span>
#     <span class="quantumsavory_regref_name">$(namestr(r.reg))</span>
#     """)
#     print(io,"""
#     <span class="quantumsavory_regref_slotindex">$(r.idx)</span>
#     </div>
#     """)
# end
function Base.show(io::IO, ::MIME"text/html", r::RegRef)
    regstr = namestr(parent(r))

    print(io, """
    <style>
    .quantumsavory_regref {
        font-family: "STIX Two Text", "Cambria Math", serif;
        min-width: 250px;
        max-width: 400px;
        line-height: 1.35;
        color: #222;
    }

    .quantumsavory_regref_heading {
        font-weight: 700;
        border-bottom: 1px solid #ddd;
        padding-bottom: 0.2em;
        margin-bottom: 0.5em;
    }

    .quantumsavory_regref_table {
        width: 100%;
        border-collapse: collapse;
    }

    .quantumsavory_regref_table td {
        padding: 0.15em 0.4em;
    }

    .quantumsavory_regref_table td:first-child {
        font-weight: 600;
        white-space: nowrap;
    }

    .quantumsavory_regref_slotindex {
        color: #2b6cb0;
        font-weight: 700;
    }

    .quantumsavory_regref_regname {
        font-family: "JuliaMono", monospace;
    }

    .quantumsavory_regref_content {
        margin-top: 0.7em;
        padding: 0.5em;
        border: 1px solid #eee;
        border-radius: 4px;
        background: #fafafa;
    }

    .quantumsavory_regref_stateindex {
        color: #805ad5;
        font-family: "JuliaMono", monospace;
    }
    </style>

    <div class="quantumsavory_show quantumsavory_regref">

        <div class="quantumsavory_regref_heading">
            Register Reference
        </div>

        <table class="quantumsavory_regref_table">
            <tr>
                <td>Register</td>
                <td class="quantumsavory_regref_regname">$regstr</td>
            </tr>
            <tr>
                <td>Slot</td>
                <td>
                    <span class="quantumsavory_regref_slotindex">$(r.idx)</span>
                    / $(length(r.reg.traits))
                </td>
            </tr>
    """)

    if !isnothing(r.reg.netparent[])
        print(io, """
            <tr>
                <td>Network</td>
                <td>$(namestr(r.reg.netparent[]))</td>
            </tr>
            <tr>
                <td>Net Index</td>
                <td>$(r.reg.netindex[])</td>
            </tr>
        """)
    end

    print(io, "</table>")

    i, s = r.reg.stateindices[r.idx], r.reg.staterefs[r.idx]

    print(io, """
        <div class="quantumsavory_regref_heading" style="margin-top:1em">
            Content
        </div>
    """)

    if isnothing(s)
        print(io, """
        <div class="quantumsavory_regref_content">
            <i>empty</i>
        </div>
        """)
    else
        print(io, """
        <div class="quantumsavory_regref_content">
            <span class="quantumsavory_regref_stateindex">$i</span>
            &nbsp;@&nbsp;
        """)

        show(IOContext(io, :compact => true), MIME"text/html"(), s)

        print(io, "</div>")
    end

    print(io, "</div>")
end

function Base.show(io::IO, m::MIME"text/html", s::StateRef)
    if get(io, :compact, false) | haskey(io, :typeinfo)
        return show(io, s)
        # print(io, "State $(typeof(s.state[]).name.module) of size $(nsubsystems(s.state[]))")
        # return
    end
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

function blochparams(state::AbstractOperator)
    nsubsystems(state) != 1 && error("Bloch parameters are only defined for single-qubit states.")

    b = basis(state)
    x = real(tr(state * sigmax(b)))
    y = real(tr(state * sigmay(b)))
    z = real(tr(state * sigmaz(b)))
    θ = acos(clamp(z, -1, 1))
    ϕ = atan(y, x)
    return (x, y, z), (θ, ϕ)
end
blochparams(state::StateVector) = blochparams(dm(state))


format_complex(z) = @sprintf("%.3f%+.3fi", real(z), imag(z))

function html_statedata(state::Ket)
    data = state.data

    if length(data) == 2
        α, β = format_complex.(data)

        return """
        <div class="quantumsavory_state">
            <span class="quantumsavory_coeff">$α</span>
            <span class="quantumsavory_basis0">|0⟩</span>
            +
            <span class="quantumsavory_coeff">$β</span>
            <span class="quantumsavory_basis1">|1⟩</span>
        </div>
        """
    elseif length(data) == 4
        α, β, γ, δ = format_complex.(data)

        return """
        <div class="quantumsavory_state">
            <span class="quantumsavory_coeff">$α</span>|00⟩ +
            <span class="quantumsavory_coeff">$β</span>|01⟩ +
            <span class="quantumsavory_coeff">$γ</span>|10⟩ +
            <span class="quantumsavory_coeff">$δ</span>|11⟩
        </div>
        """
    end
    ""
end
function html_statedata(state::Bra)
    data = state.data

    if length(data) == 2
        α, β = format_complex.(data)

        return """
        <div class="quantumsavory_state">
            <span class="quantumsavory_basis0">⟨0|</span>
            <span class="quantumsavory_coeff">$α</span>
            +
            <span class="quantumsavory_basis1">⟨1|</span>
            <span class="quantumsavory_coeff">$β</span>
        </div>
        """
    elseif length(data) == 4
        α, β, γ, δ = format_complex.(data)

        return """
        <div class="quantumsavory_state">
            ⟨00|<span class="quantumsavory_coeff">$α</span> +
            ⟨01|<span class="quantumsavory_coeff">$β</span> +
            ⟨10|<span class="quantumsavory_coeff">$γ</span> +
            ⟨11|<span class="quantumsavory_coeff">$δ</span>
        </div>
        """
    end
    ""
end
function html_statedata(state::Operator)
    data = state.data
    rows = String[]
    for i in axes(data, 1)
        cells = join(
            ("<td>$(format_complex(data[i,j]))</td>"
             for j in axes(data,2)),
            ""
        )

        push!(rows, "<tr>$cells</tr>")
    end
    """
    <table class="quantumsavory_densitymatrix">
        $(join(rows, "\n"))
    </table>
    """
end

function html_basis(state)
    if nsubsystems(state) <= 2
        return "Basis: $(basis(state))"
    end
    return "NSubsystems: $(nsubsystems(state))"
end

"""Similar to `show(io, ::MIME"", ...)`, but private to avoid piracy."""
function stateshow(io, ::MIME"text/html", state, stateref)
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
            $(html_basis(state))
        </div>
    </div>
    """)

    if nsubsystems(state) == 1
        α, β = state.data
        (x, y, z), (θ, ϕ) = blochparams(state)
        r = sqrt(x^2 + y^2 + z^2)


        print(io, """
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
        """)
    elseif nsubsystems(state) == 2
        ρA = ptrace(state, 2)
        ρB = ptrace(state, 1)

        # Bloch coordinates
        (xA, yA, zA), (θA, ϕA) = blochparams(ρA)
        (xB, yB, zB), (θB, ϕB) = blochparams(ρB)

        rA = sqrt(xA^2 + yA^2 + zA^2)
        rB = sqrt(xB^2 + yB^2 + zB^2)

        # Pauli operators
        b = SpinBasis(1//2)
        X = sigmax(b)
        Y = sigmay(b)
        Z = sigmaz(b)

        if state isa Ket
            state = dm(state)
        end

        # Correlation matrix
        xx = real(tr(state * tensor(X, X)))
        xy = real(tr(state * tensor(X, Y)))
        xz = real(tr(state * tensor(X, Z)))

        yx = real(tr(state * tensor(Y, X)))
        yy = real(tr(state * tensor(Y, Y)))
        yz = real(tr(state * tensor(Y, Z)))

        zx = real(tr(state * tensor(Z, X)))
        zy = real(tr(state * tensor(Z, Y)))
        zz = real(tr(state * tensor(Z, Z)))

        print(io, """
    <div class="quantumsavory_section">
        <div class="quantumsavory_heading">Reduced States</div>
        <div class="quantumsavory_grid">
            <table class="quantumsavory_table">
                <tr><td colspan="2"><b>Qubit A</b></td></tr>
                <tr><td>⟨X⟩</td><td>$(@sprintf("% .3f", xA))</td></tr>
                <tr><td>⟨Y⟩</td><td>$(@sprintf("% .3f", yA))</td></tr>
                <tr><td>⟨Z⟩</td><td>$(@sprintf("% .3f", zA))</td></tr>
                <tr><td>θ</td><td>$(@sprintf("%.1f", rad2deg(θA)))°</td></tr>
                <tr><td>ϕ</td><td>$(@sprintf("%.1f", rad2deg(ϕA)))°</td></tr>
                <tr><td>|r|</td><td>$(@sprintf("%.3f", rA))</td></tr>
            </table>
            <table class="quantumsavory_table">
                <tr><td colspan="2"><b>Qubit B</b></td></tr>
                <tr><td>⟨X⟩</td><td>$(@sprintf("% .3f", xB))</td></tr>
                <tr><td>⟨Y⟩</td><td>$(@sprintf("% .3f", yB))</td></tr>
                <tr><td>⟨Z⟩</td><td>$(@sprintf("% .3f", zB))</td></tr>
                <tr><td>θ</td><td>$(@sprintf("%.1f", rad2deg(θB)))°</td></tr>
                <tr><td>ϕ</td><td>$(@sprintf("%.1f", rad2deg(ϕB)))°</td></tr>
                <tr><td>|r|</td><td>$(@sprintf("%.3f", rB))</td></tr>
            </table>
        </div>
    </div>

    <div class="quantumsavory_section">
        <div class="quantumsavory_heading">Correlations</div>
        <table class="quantumsavory_densitymatrix">
            <tr>
                <td>⊗</td>
                <td><b>X</b></td>
                <td><b>Y</b></td>
                <td><b>Z</b></td>
            </tr>
            <tr>
                <td><b>X</b></td>
                <td>$(@sprintf("% .3f", xx))</td>
                <td>$(@sprintf("% .3f", xy))</td>
                <td>$(@sprintf("% .3f", xz))</td>
            </tr>
            <tr>
                <td><b>Y</b></td>
                <td>$(@sprintf("% .3f", yx))</td>
                <td>$(@sprintf("% .3f", yy))</td>
                <td>$(@sprintf("% .3f", yz))</td>
            </tr>
            <tr>
                <td><b>Z</b></td>
                <td>$(@sprintf("% .3f", zx))</td>
                <td>$(@sprintf("% .3f", zy))</td>
                <td>$(@sprintf("% .3f", zz))</td>
            </tr>
        </table>
    </div>
        """)
    elseif 3 <= nsubsystems(state) <= 5
    
    elseif nsubsystems(state) > 5
        topk = get(io, :topk, 10)
        print(io, """
    <div class="quantumsavory_section">
        <div class="quantumsavory_heading">Top $topk amplitudes</div>
    </div>
        """)
    else
        return print(io, "state of type $(typeof(state)) with $(nsubsystems(state)) subsystems does not support rich visualization")
    end
    
    print(io, """
    <div class="quantumsavory_section">
        <div class="quantumsavory_heading">State Properties</div>
        <div class="quantumsavory_properties">
            Purity: <b>$(@sprintf("%.3f", purity(state)))</b>
            <br>
            Entropy: <b>$(@sprintf("%.3f", entropy_vn(state)/log(2)))</b>
        </div>
    </div>
</div>
        """)
end
