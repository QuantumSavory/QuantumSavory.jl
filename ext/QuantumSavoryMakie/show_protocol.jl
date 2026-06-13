function Base.show(io::IO, m::MIME"image/png", prot::QuantumSavory.ProtocolZoo.AbstractProtocol)
    f = Figure()
    protshowimage(f, prot)
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

function protshowimage(subfig, prot::QuantumSavory.ProtocolZoo.EntanglerProt)
    l = Label(subfig[1,1], text="State generated between\n$(compactstr(prot.net[prot.nodeA])) and $(compactstr(prot.net[prot.nodeB]))", tellwidth=false)
    se = stateexplorer!(subfig[2,1], dm(express(prot.pairstate)))
    ldist = Label(subfig[3,1], text="Time to generate a state\n(Geometric distribution)", tellwidth=false)
    adist = Axis(subfig[4,1], xlabel="Attempt", ylabel="Success probability")
    p = prot.success_prob
    attempts = 1:Int(floor(3/p))
    Makie.stairs!(adist, attempts, (1-p).^(attempts.-1).*p; step=:center)
    Makie.vlines!(adist, [1/p], color=:gray)
    Makie.text!(adist, 1/p, 0.0, text=" Mean time:\n$(@sprintf " %.4g" (1/p))", color=:black)
end

function protshowimage(subfig, prot::QuantumSavory.ProtocolZoo.EntanglementConsumer)
    l = Label(subfig[1,1], text="Fidelity of consumed pairs between\n$(compactstr(prot.net[prot.nodeA])) and $(compactstr(prot.net[prot.nodeB]))", tellwidth=false)
    a = Axis(subfig[2,1], xlabel="Time", ylabel="Observable")
    t = [t for (t, _, _) in prot._log]
    zz = [z for (_, z, _) in prot._log]
    xx = [x for (_, _, x) in prot._log]
    scatter!(a, t, zz, label="ZZ")
    scatter!(a, t, xx, label="XX")
    hlines!(a, 0.0, color=:gray)
    hlines!(a, 1.0, color=:gray)
    axislegend(a, position=:lb)
    lh = Label(subfig[3,1], text="Histogram of time to consume a pair", tellwidth=false)
    ah = Axis(subfig[4,1], xlabel="ΔTime", ylabel="Fraction")
    Makie.hist!(ah, diff([0; t]), normalization=:probability)
    avg = sum(diff([0; t]))/length(t)
    Makie.vlines!(ah, avg, color=:gray)
    Makie.text!(ah, avg, 0.0, text=" Mean time:\n$(@sprintf " %.4g" avg)", color=:black)
end

# qTCP controllers (issue #403): a "control-plane map" of the qTCP layer drawn on
# the network topology (reusing `registernetplot_axis`). The whole network is
# colored by its visible qTCP message load (a congestion heatmap), the
# controller's node/link is highlighted, and the controller's routing/flow paths
# are traced on the graph (the quantum analog of `traceroute`/`ip route`):
#   * EndNodeController    -- traces each open flow's route (src -> dst)
#   * NetworkNodeController -- traces each visible datagram's route (node -> dst)
#   * LinkController       -- highlights the managed link edge
# A bar chart of the visible qTCP message counts accompanies the map. Everything
# is a read-only `peektags` snapshot, safe to call during a live simulation.
function protshowimage(subfig, prot::QuantumSavory.ProtocolZoo.EndNodeController)
    _qtcp_protimage(subfig, prot, [prot.node], _qtcp_flow_paths(prot),
                    "EndNodeController · qTCP endpoint @ node $(prot.node)")
end

function protshowimage(subfig, prot::QuantumSavory.ProtocolZoo.NetworkNodeController)
    _qtcp_protimage(subfig, prot, [prot.node], _qtcp_route_paths(prot),
                    "NetworkNodeController · qTCP router @ node $(prot.node)")
end

function protshowimage(subfig, prot::QuantumSavory.ProtocolZoo.LinkController)
    _qtcp_protimage(subfig, prot, [prot.nodeA, prot.nodeB], [[prot.nodeA, prot.nodeB]],
                    "LinkController · qTCP link $(prot.nodeA)–$(prot.nodeB)")
end

# node-index route s -> ... -> d (a_star); empty if unreachable
function _qtcp_node_path(g, s, d)
    s == d && return Int[s]
    es = Graphs.a_star(g, s, d)
    isempty(es) ? Int[] : vcat(s, [e.dst for e in es])
end

function _qtcp_flow_paths(prot)
    tags = QuantumSavory.peektags(QuantumSavory.messagebuffer(prot.net, prot.node))
    paths = Vector{Int}[]
    for r in QuantumSavory.ProtocolZoo._qtcp_flow_rows(tags)
        p = _qtcp_node_path(prot.net.graph, r.src, r.dst)
        length(p) >= 2 && push!(paths, p)
    end
    paths
end

function _qtcp_route_paths(prot)
    tags = QuantumSavory.peektags(QuantumSavory.messagebuffer(prot.net, prot.node))
    paths = Vector{Int}[]
    for r in QuantumSavory.ProtocolZoo._qtcp_nexthop_rows(prot.net, prot.node, tags)
        p = _qtcp_node_path(prot.net.graph, prot.node, r.dst)
        length(p) >= 2 && push!(paths, p)
    end
    paths
end

function _qtcp_protimage(subfig, prot, highlight_nodes, paths, title)
    Label(subfig[1,1], text=title, tellwidth=false, fontsize=16)

    # network-wide qTCP message-load heatmap (white -> red), per register slot
    nreg = length(prot.net.registers)
    loads = [length(QuantumSavory.peektags(QuantumSavory.messagebuffer(prot.net, n))) for n in 1:nreg]
    maxload = maximum(loads; init=0)
    function loadcolor(n)
        maxload == 0 && return Makie.RGBf(0.85, 0.85, 0.85)
        f = loads[n] / maxload
        Makie.RGBf(1.0, 1.0 - 0.7f, 1.0 - 0.7f)
    end
    slotcolor = [[loadcolor(n) for _ in 1:nsubsystems(prot.net[n])] for n in 1:nreg]

    _, ax, plt, _ = registernetplot_axis(subfig[2,1], prot.net; slotcolor=slotcolor, infocli=false, datainspector=false)
    coords = plt[:registercoords][]

    # routing/flow paths traced on the topology
    for path in paths
        length(path) >= 2 || continue
        pl = lines!(ax, [coords[n] for n in path]; color=(:orange, 0.9), linewidth=3)
        Makie.translate!(pl, 0, 0, 15)
    end

    # highlight the controller's node(s)/link
    if length(highlight_nodes) == 2
        seg = linesegments!(ax, [coords[highlight_nodes[1]], coords[highlight_nodes[2]]]; color=:dodgerblue, linewidth=4)
        Makie.translate!(seg, 0, 0, 20)
    end
    ring = scatter!(ax, [coords[n] for n in highlight_nodes];
        marker=:circle, markersize=46, color=(:dodgerblue, 0.0), strokecolor=:dodgerblue, strokewidth=4)
    Makie.translate!(ring, 0, 0, 21)

    # bar chart of the controller node's visible qTCP message counts
    primary = first(highlight_nodes)
    c = QuantumSavory.ProtocolZoo._qtcp_message_counts(QuantumSavory.peektags(QuantumSavory.messagebuffer(prot.net, primary)))
    ks = collect(keys(c))
    vs = collect(values(c))
    nz = findall(>(0), vs)
    bax = Axis(subfig[3,1]; title="visible qTCP messages @ node $(primary) (t=$(ConcurrentSim.now(prot.sim)))",
               ylabel="count")
    if isempty(nz)
        hidedecorations!(bax)
        hidespines!(bax)
        Makie.text!(bax, 0, 0; text="no qTCP messages", align=(:center, :center))
    else
        bax.xticks = (1:length(nz), String.(ks[nz]))
        bax.xticklabelrotation = pi/4
        Makie.barplot!(bax, 1:length(nz), vs[nz]; color=:dodgerblue)
    end
end
