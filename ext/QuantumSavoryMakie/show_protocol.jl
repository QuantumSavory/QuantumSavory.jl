"""Return the number of plot rows needed to render `prot`."""
protshowrows(prot) = 1

function Base.show(io::IO, m::MIME"image/png", prot::QuantumSavory.ProtocolZoo.AbstractProtocol)
    width, row_height = Makie.theme(:size)[]
    f = Figure(size=(width, row_height * protshowrows(prot) + 50))
    nodes = ProtocolZoo._protocol_nodes(prot)
    net = hasproperty(prot, :net) ? getproperty(prot, :net) : nothing
    node_labels = isnothing(net) ? string.(nodes) : [compactstr(net[node]) for node in nodes]
    location = if isempty(node_labels)
        ""
    elseif length(node_labels) == 2
        " between\n$(join(node_labels, " and "))"
    else
        " on\n$(join(node_labels, ", ", " and "))"
    end
    Label(f[1, 1], text="$(nameof(typeof(prot)))$(location)", tellwidth=false)
    protshowimage(f[2, 1], prot)
    show(io, m, f)
end

"""Similar to `show(io, ::MIME"", ...)`, but private to avoid piracy. Instead of an IO instance, it takes a Makie axis."""
function protshowimage(subfig, prot)
    a = Axis(subfig[1,1])
    hidedecorations!(a)
    hidespines!(a)
    text = "protocol of type\n$(typeof(prot))\ndoes not support rich visualization"
    text!(a,0,0;text,align=(:center,:center))
end

"""Find the first attempt with less than 0.1% tail probability."""
function _geometric_tail_cutoff(p)
    return floor(Int, log(0.001) / log1p(-p)) + 1
end

protshowrows(::QuantumSavory.ProtocolZoo.EntanglerProt) = 2

function protshowimage(subfig, prot::QuantumSavory.ProtocolZoo.EntanglerProt)
    se = stateexplorer!(subfig[1,1], dm(express(prot.pairstate)))
    ldist = Label(subfig[2,1], text="Time to generate a state\n(Geometric distribution)", tellwidth=false)
    adist = Axis(subfig[3,1], xlabel="Attempt", ylabel="Success probability")
    p = prot.success_prob
    n = _geometric_tail_cutoff(p)
    # Include two attempts after the remaining tail falls below 0.001.
    attempts = 1:(n+2)
    probabilities = (1-p).^(attempts.-1).*p
    if n < 10
        Makie.barplot!(adist, attempts, probabilities)
    else
        Makie.stairs!(adist, attempts, probabilities; step=:center)
    end
    Makie.vlines!(adist, [1/p], color=:gray)
    Makie.text!(adist, 1/p, 0.0, text=" Mean time:\n$(@sprintf " %.4g" (1/p))", color=:black)
end

"""Draw one `LinkController` timing histogram."""
function _link_timing_histogram(subfig, samples; title)
    summary = QuantumSavory.ProtocolZoo.QTCP._sample_summary(samples)
    subtitle = if isempty(samples)
        "No samples"
    else
        "n = $(length(samples)) | mean = $(@sprintf "%.4g" summary.mean) | median = $(@sprintf "%.4g" summary.median)"
    end
    axis = Axis(
        subfig;
        title,
        subtitle,
        xlabel="Time",
        ylabel="Probability density",
    )
    if isempty(samples)
        Makie.text!(
            axis,
            0.5,
            0.5;
            text="No samples",
            space=:relative,
            align=(:center, :center),
        )
    else
        Makie.hist!(axis, samples; normalization=:pdf)
    end
    return axis
end

function protshowimage(subfig, prot::QuantumSavory.ProtocolZoo.QTCP.LinkController)
    qtcp = QuantumSavory.ProtocolZoo.QTCP
    label_a = compactstr(prot.net[prot.nodeA])
    label_b = compactstr(prot.net[prot.nodeB])
    samples = qtcp._linkcontroller_samples(prot)
    layout = Makie.GridLayout(subfig[1, 1])

    Label(
        layout[1, 1:2],
        text="LinkController between\n$(label_a) and $(label_b)",
        tellwidth=false,
    )
    entangler_layout = Makie.GridLayout(layout[2, 1:2])
    protshowimage(entangler_layout, qtcp._link_entangler(prot))
    Makie.rowsize!(entangler_layout, 1, Makie.Auto(2))
    Makie.rowsize!(entangler_layout, 3, Makie.Auto(1))
    Label(
        layout[3, 1:2],
        text="Link-level request interarrival times",
        tellwidth=false,
    )
    _link_timing_histogram(
        layout[4, 1], samples.interarrival_times_a; title="From $(label_a)"
    )
    _link_timing_histogram(
        layout[4, 2], samples.interarrival_times_b; title="From $(label_b)"
    )
    Label(
        layout[5, 1:2],
        text="Link-level request sojourn times",
        tellwidth=false,
    )
    _link_timing_histogram(
        layout[6, 1:2], samples.sojourn_times; title="Completed requests"
    )
    Makie.rowsize!(layout, 2, Makie.Auto(2))
    Makie.rowsize!(layout, 4, Makie.Auto(1))
    Makie.rowsize!(layout, 6, Makie.Auto(1))
end

protshowrows(::QuantumSavory.ProtocolZoo.EntanglementConsumer) = 2

function protshowimage(subfig, prot::QuantumSavory.ProtocolZoo.EntanglementConsumer)
    a = Axis(subfig[1,1], xlabel="Time", ylabel="Observable")
    t = [t for (t, _, _) in prot._log]
    zz = [z for (_, z, _) in prot._log]
    xx = [x for (_, _, x) in prot._log]
    scatter!(a, t, zz, label="ZZ")
    scatter!(a, t, xx, label="XX")
    hlines!(a, 0.0, color=:gray)
    hlines!(a, 1.0, color=:gray)
    axislegend(a, position=:lb)
    lh = Label(subfig[2,1], text="Histogram of time to consume a pair", tellwidth=false)
    ah = Axis(subfig[3,1], xlabel="ΔTime", ylabel="Fraction")
    Makie.hist!(ah, diff([0; t]), normalization=:probability)
    avg = sum(diff([0; t]))/length(t)
    Makie.vlines!(ah, avg, color=:gray)
    Makie.text!(ah, avg, 0.0, text=" Mean time:\n$(@sprintf " %.4g" avg)", color=:black)
end
