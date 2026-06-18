styles = """<style>
    .quantumsavory_register {
        font-family: "STIX Two Text", "Cambria Math", serif;
        min-width: 300px;
        max-width: 450px;
        line-height: 1.35;
        color: #222;
    }
    .quantumsavory_stateref {
        font-family: "STIX Two Text", "Cambria Math", serif;
        min-width: 300px;
        max-width: 450px;
        line-height: 1.35;
        color: #222;
    }
    .quantumsavory_register_heading {
        font-weight: 700;
        border-bottom: 1px solid #ddd;
        padding-bottom: 0.2em;
        margin-bottom: 0.5em;
    }
    .quantumsavory_register_table {
        width: 100%;
        border-collapse: collapse;
    }
    .quantumsavory_register_table td {
        padding: 0.15em 0.4em;
    }
    .quantumsavory_register_table td:first-child {
        font-weight: 600;
        white-space: nowrap;
    }
    .quantumsavory_register_name {
        font-family: "JuliaMono", monospace;
    }
    .quantumsavory_register_traits {
        font-family: "JuliaMono", monospace;
        color: #555;
    }
    .quantumsavory_register_slots {
        margin-top: 1em;
    }
    .quantumsavory_register_slot {
        padding: 0.5em;
        border: 1px solid #eee;
        border-radius: 4px;
        background: #fafafa;
        margin-bottom: 0.4em;
    }
    .quantumsavory_register_slotindex {
        color: #2b6cb0;
        font-weight: 700;
    }
    .quantumsavory_register_stateindex {
        color: #805ad5;
        font-family: "JuliaMono", monospace;
        font-weight: 600;
    }
    .quantumsavory_register_statetype {
        color: #2f855a;
        font-family: "JuliaMono", monospace;
    }
    .quantumsavory_register_stateid {
        color: #718096;
        font-family: "JuliaMono", monospace;
        font-size: 0.9em;
    }
    .quantumsavory_register_empty {
        color: #888;
        font-style: italic;
    }
    .quantumsavory_regref {
        font-family: "STIX Two Text", "Cambria Math", serif;
        min-width: 250px;
        max-width: 450px;
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
    .quantumsavory_qubit {
        font-family: "STIX Two Text", "Cambria Math", "Latin Modern Roman", serif;
        min-width: 250px;
        max-width: 450px;
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
</style>"""

function Base.show(io::IO, ::MIME"text/html", r::Register)
    regname = namestr(r; useobjectid=false)
    print(io, """$styles
        <div class="quantumsavory_show quantumsavory_register">
            <div class="quantumsavory_register_heading">
                Register
            </div>
            <table class="quantumsavory_register_table">
                <tr>
                    <td>Name</td>
                    <td class="quantumsavory_register_name">$regname</td>
                </tr>
                <tr>
                    <td>Slots</td>
                    <td>$(length(r.traits))</td>
                </tr>
    """)
    if !isnothing(r.netparent[])
        print(io, """
            <tr>
                <td>Network</td>
                <td>$(namestr(r.netparent[]))</td>
            </tr>
            <tr>
                <td>Net Index</td>
                <td>$(r.netindex[])</td>
            </tr>
        """)
    end
    if get(io, :compact, false) | haskey(io, :typeinfo)
        print(io, "</table></div>")
        return
    end;
    print(io, """
            <tr>
                <td>Traits</td>
                <td class="quantumsavory_register_traits">
                    $(join(string.(typeof.(r.traits)), " | "))
                </td>
            </tr>
        </table>
        <div class="quantumsavory_register_heading" style="margin-top:1em">
            Slots
        </div>
        <div class="quantumsavory_register_slots">
    """)

    for (slot, (i, s)) in enumerate(zip(r.stateindices, r.staterefs))
        print(io, """
        <div class="quantumsavory_register_slot">
            <span class="quantumsavory_register_slotindex">
                Slot $slot
            </span>
        """)
        if isnothing(s)
            print(io, """
            <br>
            <span class="quantumsavory_register_empty">
                empty
            </span>
            """)
        else
            stateT = typeof(s.state[])
            statemodule = nameof(parentmodule(stateT))
            statename = nameof(stateT)
            stateid = objectid(s.state[])

            print(io, """
            <br>
            <span class="quantumsavory_register_stateindex">
                Subsystem $i
            </span>
            &nbsp;of&nbsp;
            <span class="quantumsavory_register_statetype">
                $statemodule.$statename
            </span>
            <span class="quantumsavory_register_stateid">
                ($stateid)
            </span>
            """)
        end
        print(io, """
        </div>
        """)
    end
    print(io, """
        </div>
    </div>
    """)
end

function Base.show(io::IO, ::MIME"text/html", r::RegisterNet)
    show(io, r) #placeholder
end

function Base.show(io::IO, ::MIME"text/html", r::RegRef)
    regstr = namestr(parent(r))
    if get(io, :compact, false) | haskey(io, :typeinfo)
        print(io, """$styles
            Slot <span class="quantumsavory_regref_slotindex">
                $(r.idx)/$(length(r.reg.traits))
            </span>
            of Register
            <span class="quantumsavory_regref_regname">
                $(regstr)
            </span>
        """)
        return
    end

    print(io, """
    $styles

    <div class="quantumsavory_show quantumsavory_regref">
        <div class="quantumsavory_regref_heading">
            Register Reference
        </div>
        <table class="quantumsavory_regref_table">
            <tr>
                <td>Register</td>
                <td class="quantumsavory_regref_regname">$(namestr(parent(r)))</td>
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
        <div class="quantumsavory_register_empty">
            <i>empty</i>
        </div>
        """)
    else
        print(io, """
        <div class="quantumsavory_regref_content">
            <span class="quantumsavory_regref_stateindex">$i</span>
            &nbsp;@&nbsp;
        """)

        show(IOContext(io, :compact=>true), MIME"text/html"(), s)
        print(io, "</div>")
    end
    print(io, "</div>")
end

function Base.show(io::IO, m::MIME"text/html", s::StateRef)
    if get(io, :compact, false) | haskey(io, :typeinfo)
        print(io, "State $(typeof(s.state[]).name.module) of size $(nsubsystems(s.state[]))")
        return
    end
    print(io,"""
    <div class="quantumsavory_show quantumsavory_stateref">
        <div class="quantumsavory_stateref_regrefs">
            <div class="quantumsavory_heading">Register References</div>
                <div>
    """)
    for rr in slots(s)
        i = rr.reg.stateindices[rr.idx]
        print(io, "<div>")
        print(io, """• <span class="quantumsavory_regref_stateindex">Subsystem $i</span> @""")
        show(IOContext(io, :compact => true), m, rr)
        print(io, "</div>")
    end
    print(io,"""
                </div>
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

function correleation_2q(state::AbstractOperator)
    nsubsystems(state) != 2 && error("Two-qubit correlation is only defined for two-qubit states.")

    b = SpinBasis(1//2)
    X = sigmax(b)
    Y = sigmay(b)
    Z = sigmaz(b)

    xx = real(tr(state * tensor(X, X)))
    xy = real(tr(state * tensor(X, Y)))
    xz = real(tr(state * tensor(X, Z)))

    yx = real(tr(state * tensor(Y, X)))
    yy = real(tr(state * tensor(Y, Y)))
    yz = real(tr(state * tensor(Y, Z)))

    zx = real(tr(state * tensor(Z, X)))
    zy = real(tr(state * tensor(Z, Y)))
    zz = real(tr(state * tensor(Z, Z)))

    return xx, xy, xz, yx, yy, yz, zx, zy, zz
end
correleation_2q(state::StateVector) = correleation_2q(dm(state))


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
    nsubsystems(state) >= 3 && return ""

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
$styles

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

        xx, xy, xz, yx, yy, yz, zx, zy, zz = correleation_2q(state)

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
    else
        topk = get(io, :topk, 8)

        print(io, """
        <div class="quantumsavory_section">
            <div class="quantumsavory_heading">Top $topk amplitudes</div>

            <table class="quantumsavory_table">
        """)
        print(io, topk_stateinfo(state, topk))
        print(io, """
            </table>
        </div>
        """)
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


function topk_stateinfo(state::AbstractOperator, topk)
    probs = collect(enumerate(real.(diag(state.data))))
    sort!(probs; by = x -> x[2], rev = true)
    probs = first(probs, min(topk, length(probs)))

    res = """
        <tr>
            <td><b>Basis State</b></td>
            <td><b>Probability</b></td>
        </tr>
    """
    for (idx, prob) in probs
        bits = string(idx - 1; base = 2, pad = nsubsystems(state))

        res *= """
        <tr>
            <td>$(_basislabel(state, bits))</td>
            <td>$(@sprintf("%.3f", prob))</td>
        </tr>
        """
    end
    return res
end

function topk_stateinfo(state::StateVector, topk)
    amps = collect(enumerate(state.data))
    sort!(amps; by = x -> abs(x[2]), rev = true)
    amps = first(amps, min(topk, length(amps)))

    res = """
        <tr>
            <td><b>Basis State</b></td>
            <td><b>|Amplitude|</b></td>
            <td><b>Phase</b></td>
        </tr>
    """
    for (idx, amp) in amps
        bits = string(idx - 1; base = 2, pad = nsubsystems(state))
        res *= """
        <tr>
            <td>$(_basislabel(state, bits))</td>
            <td>$(@sprintf("%.3f", abs(amp)))</td>
            <td>$(@sprintf("%.1f", rad2deg(angle(amp))))°</td>
        </tr>
        """
    end

    return res
end

_basislabel(::AbstractKet, bits) = "|$bits⟩"
_basislabel(::AbstractBra, bits) = "⟨$bits|"
_basislabel(::AbstractOperator, bits) = bits