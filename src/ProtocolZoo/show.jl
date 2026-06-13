function Base.show(io::IO, m::MIME"text/html", p::AbstractProtocol)
    print(io,
    """
    <div class="quantumsavory_show quantumsavory_protocol quantumsavory_protocol_unknown">
    state of type <code class="quantumsavory_typename quantumsavory_protocol_typename">$(typeof(p))</code> does not support rich visualization in HTML
    </div>
    """)
end

function Base.show(io::IO, m::MIME"text/html", p::EntanglerProt)
    label_a = compactstr(p.net[p.nodeA])
    label_b = compactstr(p.net[p.nodeB])
    p_success = p.success_prob
    mean_time = 1/p_success
    print(io,
    """
    <div class="quantumsavory_show quantumsavory_protocol quantumsavory_protocol_entangler">
      <h1><code class="quantumsavory_typename quantumsavory_protocol_typename">EntanglerProt</code> protocol</h1>
      <address>on <b>$(label_a)</b> and <b>$(label_b)</b></address>
      <dl>
        <dt>Success probability per attempt</dt>
        <dd>$(p_success)</dd>
        <dt>Mean time to generate a state</dt>
        <dd>$(mean_time)</dd>
      </dl>
    </div>
    """)
end

function Base.show(io::IO, m::MIME"text/html", p::EntanglementConsumer)
    consumedpairs = length(p._log)
    total_time = length(p._log) > 0 ? last(p._log).t : 0.0
    average_time_between_pairs = total_time / consumedpairs
    observable1 = "ZZ"
    observable2 = "XX"
    observable1_average = length(p._log) > 0 ? sum(x -> x.obs1, p._log) / length(p._log) : 0.0
    observable2_average = length(p._log) > 0 ? sum(x -> x.obs2, p._log) / length(p._log) : 0.0
    print(io,
    """
    <div class="quantumsavory_show quantumsavory_protocol quantumsavory_protocol_entanglement_consumer">
    <h1><code class="quantumsavory_typename quantumsavory_protocol_typename">EntanglementConsumer</code> protocol</h1>
    <address>on nodes $(compactstr(p.net[p.nodeA])) and $(compactstr(p.net[p.nodeB]))</address>
    <dl>
    <dt>Consumed pairs</dt>
    <dd>$(consumedpairs)</dd>
    <dt>Total time</dt>
    <dd>$(total_time)</dd>
    <dt>Average time between pairs</dt>
    <dd>$(average_time_between_pairs)</dd>
    <dt>Average observable of $(observable1) and $(observable2)</dt>
    <dd>$(observable1_average) | $(observable2_average)</dd>
    </dl>
    <h2>Log</h2>
    $(pretty_table(String, p._log, column_labels=["Time", "Observable 1", "Observable 2"], formatters=[PrettyTables.fmt__printf("%5.3f")], backend=:html, maximum_number_of_rows=25))
    </div>
    """)
end


###
# qTCP controller displays (issue #403)
#
# The qTCP controllers are the quantum analog of the TCP/IP control plane, so
# their displays follow that mental model:
#   * `EndNodeController`    -- the endpoint/socket layer: open flows + datagram queue
#   * `NetworkNodeController` -- the router: neighbors + inferred next-hop routing table
#   * `LinkController`       -- the link layer: endpoint registers + pending link-level messages
# All displays are read-only summaries built from a one-shot snapshot of the
# node's message buffer (`peektags`), so they are safe to call during a live
# simulation and deterministic across platforms/threads.
###

import Graphs
using .QTCP: QDatagramSuccess  # the only qTCP message type not exported from the QTCP submodule

"""The qTCP message/tag types summarized in the controller displays."""
const _QTCP_MESSAGE_HEADS = (Flow, QDatagram, QDatagramSuccess, LinkLevelRequest,
    LinkLevelReply, LinkLevelReplyAtHop, LinkLevelReplyAtSource, QTCPPairBegin, QTCPPairEnd)

"""Read-only snapshot of the tags currently visible in node `node`'s message buffer."""
_qtcp_tags(net::RegisterNet, node::Int) = QuantumSavory.peektags(messagebuffer(net, node))

"""The `DataType` head of a `Tag`, or `nothing` if the tag is not type-headed."""
function _qtcp_head(tag::Tag)
    length(tag) >= 1 || return nothing
    h = tag[1]
    h isa DataType ? h : nothing
end

"""Counts of the visible qTCP message/tag types in a `tags` snapshot, as an ordered `NamedTuple`."""
function _qtcp_message_counts(tags)
    heads = _QTCP_MESSAGE_HEADS
    ks = (:Flow, :QDatagram, :QDatagramSuccess, :LinkLevelRequest, :LinkLevelReply,
          :LinkLevelReplyAtHop, :LinkLevelReplyAtSource, :QTCPPairBegin, :QTCPPairEnd)
    NamedTuple{ks}(ntuple(i -> count(t -> _qtcp_head(t) === heads[i], tags), length(heads)))
end

"""Visible `Flow` tags as `(uuid, src, dst, npairs)` rows, sorted deterministically."""
function _qtcp_flow_rows(tags)
    rows = NamedTuple{(:uuid, :src, :dst, :npairs), NTuple{4,Int}}[]
    for t in tags
        _qtcp_head(t) === Flow || continue
        push!(rows, (uuid=Int(t[5]), src=Int(t[2]), dst=Int(t[3]), npairs=Int(t[4])))
    end
    sort!(rows; by=r->(r.src, r.dst, r.uuid))
end

"""Inferred next hops for visible `QDatagram` tags not yet at their destination,
as `(uuid, seq, dst, nexthop)` rows. Uses `Graphs.a_star`; rows with no path are skipped."""
function _qtcp_nexthop_rows(net::RegisterNet, node::Int, tags)
    rows = NamedTuple{(:uuid, :seq, :dst, :nexthop), NTuple{4,Int}}[]
    for t in tags
        _qtcp_head(t) === QDatagram || continue
        dst = Int(t[4])
        dst == node && continue
        path = Graphs.a_star(net.graph, node, dst)
        isempty(path) && continue
        push!(rows, (uuid=Int(t[2]), seq=Int(t[6]), dst=dst, nexthop=first(path).dst))
    end
    sort!(rows; by=r->(r.uuid, r.seq))
end

"""Render a vector of `NamedTuple` rows as an HTML table, or a placeholder when empty."""
function _qtcp_table_html(rows, labels)
    isempty(rows) && return "<p><em>none</em></p>"
    pretty_table(String, rows; column_labels=labels, backend=:html)
end

_qtcp_counts_html(c) = _qtcp_table_html([(message=String(k), count=v) for (k,v) in pairs(c)], ["qTCP message", "count"])

# --- EndNodeController ---

function Base.show(io::IO, p::EndNodeController)
    tags = _qtcp_tags(p.net, p.node)
    c = _qtcp_message_counts(tags)
    print(io, "EndNodeController on ", compactstr(p.net[p.node]), " (node ", p.node, ") | t=", now(p.sim),
              " | ", sum(values(c)), " qTCP messages | ", length(_qtcp_flow_rows(tags)), " flows")
end

function Base.show(io::IO, m::MIME"text/html", p::EndNodeController)
    tags = _qtcp_tags(p.net, p.node)
    c = _qtcp_message_counts(tags)
    flows = _qtcp_flow_rows(tags)
    print(io,
    """
    <div class="quantumsavory_show quantumsavory_protocol quantumsavory_protocol_qtcp_endnode">
      <h1><code class="quantumsavory_typename quantumsavory_protocol_typename">EndNodeController</code> protocol <small>(qTCP endpoint)</small></h1>
      <address>on <b>$(compactstr(p.net[p.node]))</b> (node $(p.node)) at simulation time $(now(p.sim))</address>
      <h2>Open flows ($(length(flows)))</h2>
      $(_qtcp_table_html(flows, ["uuid", "src", "dst", "npairs"]))
      <h2>Visible qTCP messages</h2>
      $(_qtcp_counts_html(c))
      <dl>
        <dt>Completed pair tags (begin / end)</dt>
        <dd>$(c.QTCPPairBegin) / $(c.QTCPPairEnd)</dd>
      </dl>
    </div>
    """)
end

# --- NetworkNodeController ---

function Base.show(io::IO, p::NetworkNodeController)
    nbrs = sort!(collect(Graphs.neighbors(p.net.graph, p.node)))
    c = _qtcp_message_counts(_qtcp_tags(p.net, p.node))
    print(io, "NetworkNodeController on ", compactstr(p.net[p.node]), " (node ", p.node, ") | degree ", length(nbrs),
              " | ", c.QDatagram, " datagrams visible | t=", now(p.sim))
end

function Base.show(io::IO, m::MIME"text/html", p::NetworkNodeController)
    tags = _qtcp_tags(p.net, p.node)
    c = _qtcp_message_counts(tags)
    nbrs = sort!(collect(Graphs.neighbors(p.net.graph, p.node)))
    hops = _qtcp_nexthop_rows(p.net, p.node, tags)
    print(io,
    """
    <div class="quantumsavory_show quantumsavory_protocol quantumsavory_protocol_qtcp_networknode">
      <h1><code class="quantumsavory_typename quantumsavory_protocol_typename">NetworkNodeController</code> protocol <small>(qTCP router)</small></h1>
      <address>on <b>$(compactstr(p.net[p.node]))</b> (node $(p.node)) at simulation time $(now(p.sim))</address>
      <dl>
        <dt>Neighbors</dt><dd>$(isempty(nbrs) ? "none" : join(nbrs, ", "))</dd>
        <dt>Degree</dt><dd>$(length(nbrs))</dd>
        <dt>Visible QDatagram / LinkLevelReply</dt><dd>$(c.QDatagram) / $(c.LinkLevelReply)</dd>
      </dl>
      <h2>Inferred routing table</h2>
      $(_qtcp_table_html(hops, ["uuid", "seq", "dst", "next hop"]))
      <h2>Visible qTCP messages</h2>
      $(_qtcp_counts_html(c))
    </div>
    """)
end

# --- LinkController ---

function Base.show(io::IO, p::LinkController)
    print(io, "LinkController between ", compactstr(p.net[p.nodeA]), " (node ", p.nodeA, ") and ",
              compactstr(p.net[p.nodeB]), " (node ", p.nodeB, ") | t=", now(p.sim))
end

function Base.show(io::IO, m::MIME"text/html", p::LinkController)
    cA = _qtcp_message_counts(_qtcp_tags(p.net, p.nodeA))
    cB = _qtcp_message_counts(_qtcp_tags(p.net, p.nodeB))
    endpoints = [
        (endpoint="A", node=p.nodeA, register=compactstr(p.net[p.nodeA]), slots=nsubsystems(p.net[p.nodeA])),
        (endpoint="B", node=p.nodeB, register=compactstr(p.net[p.nodeB]), slots=nsubsystems(p.net[p.nodeB])),
    ]
    linklevel = [
        (endpoint="A (node $(p.nodeA))", request=cA.LinkLevelRequest, reply=cA.LinkLevelReply, reply_at_hop=cA.LinkLevelReplyAtHop),
        (endpoint="B (node $(p.nodeB))", request=cB.LinkLevelRequest, reply=cB.LinkLevelReply, reply_at_hop=cB.LinkLevelReplyAtHop),
    ]
    print(io,
    """
    <div class="quantumsavory_show quantumsavory_protocol quantumsavory_protocol_qtcp_link">
      <h1><code class="quantumsavory_typename quantumsavory_protocol_typename">LinkController</code> protocol <small>(qTCP link layer)</small></h1>
      <address>between node $(p.nodeA) and node $(p.nodeB) at simulation time $(now(p.sim))</address>
      <h2>Endpoints</h2>
      $(_qtcp_table_html(endpoints, ["", "node", "register", "slots"]))
      <h2>Pending link-level messages</h2>
      $(_qtcp_table_html(linklevel, ["endpoint", "request", "reply", "reply@hop"]))
    </div>
    """)
end
