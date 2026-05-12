import Graphs

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

const _QTCP_SHOW_MESSAGE_TYPES = (
    Flow,
    QDatagram,
    QTCP.QDatagramSuccess,
    LinkLevelRequest,
    LinkLevelReply,
    LinkLevelReplyAtSource,
    LinkLevelReplyAtHop,
    QTCPPairBegin,
    QTCPPairEnd,
)

_qtcp_message_label(::Type{T}) where {T} = String(nameof(T))

function _html_escape(x)
    replace(string(x), "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\"" => "&quot;")
end

function _qtcp_tag_type(tag::Tag)
    length(tag) == 0 && return nothing
    first_field = tag[1]
    first_field isa DataType || return nothing
    return first_field in _QTCP_SHOW_MESSAGE_TYPES ? first_field : nothing
end

function _qtcp_message_counts(mb::MessageBuffer)
    counts = Dict{DataType,Int}(T => 0 for T in _QTCP_SHOW_MESSAGE_TYPES)
    for entry in mb.buffer
        tag_type = _qtcp_tag_type(entry.tag)
        isnothing(tag_type) || (counts[tag_type] += 1)
    end
    return counts
end

function _qtcp_message_count_summary(counts)
    parts = String[]
    for T in _QTCP_SHOW_MESSAGE_TYPES
        count = counts[T]
        count == 0 || push!(parts, "$(_qtcp_message_label(T))=$(count)")
    end
    return isempty(parts) ? "no visible qTCP messages" : join(parts, ", ")
end

function _qtcp_message_counts_table(counts)
    rows = join((
        "<tr><td><code>$(_html_escape(_qtcp_message_label(T)))</code></td><td>$(counts[T])</td></tr>"
        for T in _QTCP_SHOW_MESSAGE_TYPES
    ), "\n")
    return """
    <table>
      <thead><tr><th>Message type</th><th>Visible count</th></tr></thead>
      <tbody>
      $(rows)
      </tbody>
    </table>
    """
end

function _qtcp_counts_by_node_table(net, nodes)
    header = join(("<th>Node $(node)</th>" for node in nodes), "")
    rows = String[]
    for T in _QTCP_SHOW_MESSAGE_TYPES
        cells = join(("<td>$(_qtcp_message_counts(messagebuffer(net, node))[T])</td>" for node in nodes), "")
        push!(rows, "<tr><td><code>$(_html_escape(_qtcp_message_label(T)))</code></td>$(cells)</tr>")
    end
    return """
    <table>
      <thead><tr><th>Message type</th>$(header)</tr></thead>
      <tbody>
      $(join(rows, "\n"))
      </tbody>
    </table>
    """
end

function _qtcp_next_hop(net::RegisterNet, node::Int, dst::Int)
    node == dst && return "destination"
    path = Graphs.a_star(net.graph, node, dst)
    isempty(path) && return "unreachable"
    return string(first(path).dst)
end

function _qtcp_qdatagram_routes_table(p::NetworkNodeController)
    rows = String[]
    mb = messagebuffer(p.net, p.node)
    for entry in mb.buffer
        _qtcp_tag_type(entry.tag) === QDatagram || continue
        flow_uuid = entry.tag[2]
        flow_src = entry.tag[3]
        flow_dst = entry.tag[4]
        seq_num = entry.tag[6]
        next_hop = _qtcp_next_hop(p.net, p.node, flow_dst)
        push!(rows,
            "<tr><td>$(flow_uuid).$(seq_num)</td><td>$(flow_src)</td><td>$(flow_dst)</td><td>$(_html_escape(next_hop))</td></tr>"
        )
    end
    isempty(rows) && return "<p>No visible QDatagram routing work.</p>"
    return """
    <table>
      <thead><tr><th>Flow.sequence</th><th>Source</th><th>Destination</th><th>Next hop</th></tr></thead>
      <tbody>
      $(join(rows, "\n"))
      </tbody>
    </table>
    """
end

function _qtcp_endpoint_table(net::RegisterNet, nodes)
    rows = join((
        "<tr><td>$(node)</td><td>$(_html_escape(compactstr(net[node])))</td><td>$(length(net[node]))</td><td>$(_html_escape(_qtcp_message_count_summary(_qtcp_message_counts(messagebuffer(net, node)))))</td></tr>"
        for node in nodes
    ), "\n")
    return """
    <table>
      <thead><tr><th>Node</th><th>Register</th><th>Slots</th><th>Visible qTCP messages</th></tr></thead>
      <tbody>
      $(rows)
      </tbody>
    </table>
    """
end

function _qtcp_text_lines(p::EndNodeController)
    counts = _qtcp_message_counts(messagebuffer(p.net, p.node))
    [
        "EndNodeController qTCP protocol",
        "node: $(p.node) ($(compactstr(p.net[p.node])))",
        "time: $(now(p.sim))",
        "visible messages: $(_qtcp_message_count_summary(counts))",
        "completed pair tags: $(counts[QTCPPairBegin] + counts[QTCPPairEnd])",
    ]
end

function _qtcp_text_lines(p::NetworkNodeController)
    counts = _qtcp_message_counts(messagebuffer(p.net, p.node))
    neighbors = collect(Graphs.neighbors(p.net.graph, p.node))
    [
        "NetworkNodeController qTCP protocol",
        "node: $(p.node) ($(compactstr(p.net[p.node])))",
        "time: $(now(p.sim))",
        "neighbors: $(isempty(neighbors) ? "none" : join(neighbors, ", "))",
        "visible messages: $(_qtcp_message_count_summary(counts))",
    ]
end

function _qtcp_text_lines(p::LinkController)
    counts_a = _qtcp_message_counts(messagebuffer(p.net, p.nodeA))
    counts_b = _qtcp_message_counts(messagebuffer(p.net, p.nodeB))
    [
        "LinkController qTCP protocol",
        "endpoints: $(p.nodeA) ($(compactstr(p.net[p.nodeA]))) <-> $(p.nodeB) ($(compactstr(p.net[p.nodeB])))",
        "time: $(now(p.sim))",
        "node $(p.nodeA) visible messages: $(_qtcp_message_count_summary(counts_a))",
        "node $(p.nodeB) visible messages: $(_qtcp_message_count_summary(counts_b))",
    ]
end

_qtcp_text_summary(p) = join(_qtcp_text_lines(p), "\n")

Base.show(io::IO, p::EndNodeController) = print(io, _qtcp_text_summary(p))
Base.show(io::IO, p::NetworkNodeController) = print(io, _qtcp_text_summary(p))
Base.show(io::IO, p::LinkController) = print(io, _qtcp_text_summary(p))

function Base.show(io::IO, m::MIME"text/html", p::EndNodeController)
    counts = _qtcp_message_counts(messagebuffer(p.net, p.node))
    print(io,
    """
    <div class="quantumsavory_show quantumsavory_protocol quantumsavory_protocol_qtcp quantumsavory_protocol_qtcp_end_node">
      <h1><code class="quantumsavory_typename quantumsavory_protocol_typename">EndNodeController</code> qTCP protocol</h1>
      <address>on node <b>$(p.node)</b> (<b>$(_html_escape(compactstr(p.net[p.node])))</b>)</address>
      <dl>
        <dt>Simulation time</dt><dd>$(now(p.sim))</dd>
        <dt>Register slots</dt><dd>$(length(p.net[p.node]))</dd>
        <dt>Visible qTCP messages</dt><dd>$(_html_escape(_qtcp_message_count_summary(counts)))</dd>
        <dt>Completed pair tags</dt><dd>$(counts[QTCPPairBegin] + counts[QTCPPairEnd])</dd>
      </dl>
      <h2>Message buffer</h2>
      $(_qtcp_message_counts_table(counts))
    </div>
    """)
end

function Base.show(io::IO, m::MIME"text/html", p::NetworkNodeController)
    counts = _qtcp_message_counts(messagebuffer(p.net, p.node))
    neighbors = collect(Graphs.neighbors(p.net.graph, p.node))
    print(io,
    """
    <div class="quantumsavory_show quantumsavory_protocol quantumsavory_protocol_qtcp quantumsavory_protocol_qtcp_network_node">
      <h1><code class="quantumsavory_typename quantumsavory_protocol_typename">NetworkNodeController</code> qTCP protocol</h1>
      <address>on node <b>$(p.node)</b> (<b>$(_html_escape(compactstr(p.net[p.node])))</b>)</address>
      <dl>
        <dt>Simulation time</dt><dd>$(now(p.sim))</dd>
        <dt>Neighbors</dt><dd>$(_html_escape(isempty(neighbors) ? "none" : join(neighbors, ", ")))</dd>
        <dt>Degree</dt><dd>$(Graphs.degree(p.net.graph, p.node))</dd>
        <dt>Visible qTCP messages</dt><dd>$(_html_escape(_qtcp_message_count_summary(counts)))</dd>
      </dl>
      <h2>Message buffer</h2>
      $(_qtcp_message_counts_table(counts))
      <h2>Visible QDatagram routes</h2>
      $(_qtcp_qdatagram_routes_table(p))
    </div>
    """)
end

function Base.show(io::IO, m::MIME"text/html", p::LinkController)
    print(io,
    """
    <div class="quantumsavory_show quantumsavory_protocol quantumsavory_protocol_qtcp quantumsavory_protocol_qtcp_link">
      <h1><code class="quantumsavory_typename quantumsavory_protocol_typename">LinkController</code> qTCP protocol</h1>
      <address>between node <b>$(p.nodeA)</b> (<b>$(_html_escape(compactstr(p.net[p.nodeA])))</b>) and node <b>$(p.nodeB)</b> (<b>$(_html_escape(compactstr(p.net[p.nodeB])))</b>)</address>
      <dl>
        <dt>Simulation time</dt><dd>$(now(p.sim))</dd>
        <dt>Endpoint nodes</dt><dd>$(p.nodeA) and $(p.nodeB)</dd>
      </dl>
      <h2>Endpoint registers</h2>
      $(_qtcp_endpoint_table(p.net, (p.nodeA, p.nodeB)))
      <h2>Endpoint qTCP message buffers</h2>
      $(_qtcp_counts_by_node_table(p.net, (p.nodeA, p.nodeB)))
    </div>
    """)
end
