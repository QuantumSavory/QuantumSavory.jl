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

const _QTCP_MESSAGE_HEADS = (
    Flow,
    QDatagram,
    QTCP.QDatagramSuccess,
    LinkLevelRequest,
    LinkLevelReply,
    LinkLevelReplyAtHop,
    LinkLevelReplyAtSource,
    QTCPPairBegin,
    QTCPPairEnd,
)

function _qtcp_message_counts(mb)
    counts = Dict{DataType, Int}(head => 0 for head in _QTCP_MESSAGE_HEADS)
    for entry in mb.buffer
        head = typeof(entry.tag)
        if haskey(counts, head)
            counts[head] += 1
        end
    end
    return counts
end

_qtcp_count(counts, head) = get(counts, head, 0)

function _qtcp_pair_summaries(mb, pair_head; limit=6)
    pairs = String[]
    for entry in mb.buffer
        tag = entry.tag
        tag isa pair_head || continue
        push!(pairs, "$(tag.flow_uuid).$(tag.seq_num)@slot$(tag.memory_slot)")
        length(pairs) >= limit && break
    end
    return pairs
end

function _qtcp_visible_qdatagrams(mb)
    datagrams = NamedTuple{(:flow_uuid, :flow_src, :flow_dst, :seq_num), Tuple{Int, Int, Int, Int}}[]
    for entry in mb.buffer
        tag = entry.tag
        tag isa QDatagram || continue
        push!(datagrams, (
            flow_uuid = tag.flow_uuid,
            flow_src = tag.flow_src,
            flow_dst = tag.flow_dst,
            seq_num = tag.seq_num,
        ))
    end
    return datagrams
end

function _qtcp_inferred_next_hops(graph, node, datagrams)
    hops = Dict{Tuple{Int, Int, Int}, Int}()
    for d in datagrams
        key = (d.flow_uuid, d.seq_num, d.flow_dst)
        haskey(hops, key) && continue
        try
            path = Graphs.a_star(graph, node, d.flow_dst)
            isempty(path) || (hops[key] = first(path).dst)
    catch err
      @debug "qTCP display next-hop inference failed" node d.flow_dst exception=err
        end
    end
    return hops
end

function Base.show(io::IO, p::EndNodeController)
    mb = messagebuffer(p.net, p.node)
    counts = _qtcp_message_counts(mb)
    begin_pairs = _qtcp_pair_summaries(mb, QTCPPairBegin)
    end_pairs = _qtcp_pair_summaries(mb, QTCPPairEnd)
    print(io,
        "EndNodeController(node=$(p.node), time=$(now(p.sim)), register=$(compactstr(p.net[p.node]))) ",
        "Flow=$(_qtcp_count(counts, Flow)), QDatagram=$(_qtcp_count(counts, QDatagram)), ",
        "QDatagramSuccess=$(_qtcp_count(counts, QTCP.QDatagramSuccess)), ",
        "LinkLevelReplyAtSource=$(_qtcp_count(counts, LinkLevelReplyAtSource)), ",
        "QTCPPairBegin=$(_qtcp_count(counts, QTCPPairBegin)), QTCPPairEnd=$(_qtcp_count(counts, QTCPPairEnd))",
    )
    if !isempty(begin_pairs) || !isempty(end_pairs)
        print(io, " | pairs begin=[", join(begin_pairs, ", "), "] end=[", join(end_pairs, ", "), "]")
    end
end

function Base.show(io::IO, p::NetworkNodeController)
    mb = messagebuffer(p.net, p.node)
    counts = _qtcp_message_counts(mb)
    datagrams = _qtcp_visible_qdatagrams(mb)
    incoming = count(d -> d.flow_src != p.node, datagrams)
    outgoing = count(d -> d.flow_src == p.node, datagrams)
    next_hops = _qtcp_inferred_next_hops(p.net.graph, p.node, datagrams)
    next_hops_str = isempty(next_hops) ? "none" : join(("$(flow_uuid).$(seq_num)->$(hop)" for ((flow_uuid, seq_num, _), hop) in sort(collect(next_hops); by=first)), ", ")
    neighbors = sort!(collect(Graphs.neighbors(p.net.graph, p.node)))
    print(io,
        "NetworkNodeController(node=$(p.node), degree=$(Graphs.degree(p.net.graph, p.node)), neighbors=$(neighbors)) ",
        "QDatagram(in=$incoming, out=$outgoing), ",
        "LinkLevelReply=$(_qtcp_count(counts, LinkLevelReply)), ",
        "LinkLevelReplyAtHop=$(_qtcp_count(counts, LinkLevelReplyAtHop)), next_hops=$next_hops_str",
    )
end

function Base.show(io::IO, p::LinkController)
    mb_a = messagebuffer(p.net, p.nodeA)
    mb_b = messagebuffer(p.net, p.nodeB)
    counts_a = _qtcp_message_counts(mb_a)
    counts_b = _qtcp_message_counts(mb_b)
    print(io,
        "LinkController($(p.nodeA)<->$(p.nodeB), time=$(now(p.sim))) ",
        "A[req=$(_qtcp_count(counts_a, LinkLevelRequest)), reply=$(_qtcp_count(counts_a, LinkLevelReply)), at_hop=$(_qtcp_count(counts_a, LinkLevelReplyAtHop))] ",
        "B[req=$(_qtcp_count(counts_b, LinkLevelRequest)), reply=$(_qtcp_count(counts_b, LinkLevelReply)), at_hop=$(_qtcp_count(counts_b, LinkLevelReplyAtHop))]",
    )
end

function Base.show(io::IO, m::MIME"text/html", p::EndNodeController)
    mb = messagebuffer(p.net, p.node)
    counts = _qtcp_message_counts(mb)
    begin_pairs = _qtcp_pair_summaries(mb, QTCPPairBegin)
    end_pairs = _qtcp_pair_summaries(mb, QTCPPairEnd)
    print(io,
    """
    <div class="quantumsavory_show quantumsavory_protocol quantumsavory_protocol_qtcp_end_node">
      <h1><code class="quantumsavory_typename quantumsavory_protocol_typename">EndNodeController</code> protocol</h1>
      <address>node $(p.node) on <b>$(compactstr(p.net[p.node]))</b> at time $(now(p.sim))</address>
      <dl>
        <dt>Network label</dt>
        <dd>$(compactstr(p.net))</dd>
      </dl>
      <table>
        <thead>
          <tr><th>Message</th><th>Count</th></tr>
        </thead>
        <tbody>
          <tr><td>Flow</td><td>$(_qtcp_count(counts, Flow))</td></tr>
          <tr><td>QDatagram</td><td>$(_qtcp_count(counts, QDatagram))</td></tr>
          <tr><td>QDatagramSuccess</td><td>$(_qtcp_count(counts, QTCP.QDatagramSuccess))</td></tr>
          <tr><td>LinkLevelReplyAtSource</td><td>$(_qtcp_count(counts, LinkLevelReplyAtSource))</td></tr>
          <tr><td>QTCPPairBegin</td><td>$(_qtcp_count(counts, QTCPPairBegin))</td></tr>
          <tr><td>QTCPPairEnd</td><td>$(_qtcp_count(counts, QTCPPairEnd))</td></tr>
        </tbody>
      </table>
      <p><b>Completed pair tags at node:</b> begin [$(isempty(begin_pairs) ? "none" : join(begin_pairs, ", "))], end [$(isempty(end_pairs) ? "none" : join(end_pairs, ", "))]</p>
    </div>
    """)
end

function Base.show(io::IO, m::MIME"text/html", p::NetworkNodeController)
    mb = messagebuffer(p.net, p.node)
    counts = _qtcp_message_counts(mb)
    datagrams = _qtcp_visible_qdatagrams(mb)
    incoming = count(d -> d.flow_src != p.node, datagrams)
    outgoing = count(d -> d.flow_src == p.node, datagrams)
    next_hops = _qtcp_inferred_next_hops(p.net.graph, p.node, datagrams)
    next_hops_str = isempty(next_hops) ? "none" : join(("$(flow_uuid).$(seq_num)->$(hop)" for ((flow_uuid, seq_num, _), hop) in sort(collect(next_hops); by=first)), ", ")
    neighbors = sort!(collect(Graphs.neighbors(p.net.graph, p.node)))
    print(io,
    """
    <div class="quantumsavory_show quantumsavory_protocol quantumsavory_protocol_qtcp_network_node">
      <h1><code class="quantumsavory_typename quantumsavory_protocol_typename">NetworkNodeController</code> protocol</h1>
      <address>node $(p.node) on <b>$(compactstr(p.net[p.node]))</b></address>
      <dl>
        <dt>Degree</dt>
        <dd>$(Graphs.degree(p.net.graph, p.node))</dd>
        <dt>Neighbors</dt>
        <dd>$(join(neighbors, ", "))</dd>
        <dt>Visible QDatagram traffic</dt>
        <dd>incoming $(incoming), outgoing $(outgoing)</dd>
        <dt>Inferred next hops</dt>
        <dd>$(next_hops_str)</dd>
      </dl>
      <table>
        <thead>
          <tr><th>Message</th><th>Count</th></tr>
        </thead>
        <tbody>
          <tr><td>QDatagram</td><td>$(_qtcp_count(counts, QDatagram))</td></tr>
          <tr><td>LinkLevelReply</td><td>$(_qtcp_count(counts, LinkLevelReply))</td></tr>
          <tr><td>LinkLevelReplyAtHop</td><td>$(_qtcp_count(counts, LinkLevelReplyAtHop))</td></tr>
        </tbody>
      </table>
    </div>
    """)
end

function Base.show(io::IO, m::MIME"text/html", p::LinkController)
    mb_a = messagebuffer(p.net, p.nodeA)
    mb_b = messagebuffer(p.net, p.nodeB)
    counts_a = _qtcp_message_counts(mb_a)
    counts_b = _qtcp_message_counts(mb_b)
    print(io,
    """
    <div class="quantumsavory_show quantumsavory_protocol quantumsavory_protocol_qtcp_link">
      <h1><code class="quantumsavory_typename quantumsavory_protocol_typename">LinkController</code> protocol</h1>
      <address>endpoints $(p.nodeA) and $(p.nodeB) at time $(now(p.sim))</address>
      <table>
        <thead>
          <tr><th>Endpoint</th><th>Register</th><th>Slots</th><th>LinkLevelRequest</th><th>LinkLevelReply</th><th>LinkLevelReplyAtHop</th></tr>
        </thead>
        <tbody>
          <tr>
            <td>$(p.nodeA)</td>
            <td>$(compactstr(p.net[p.nodeA]))</td>
            <td>$(nsubsystems(p.net[p.nodeA]))</td>
            <td>$(_qtcp_count(counts_a, LinkLevelRequest))</td>
            <td>$(_qtcp_count(counts_a, LinkLevelReply))</td>
            <td>$(_qtcp_count(counts_a, LinkLevelReplyAtHop))</td>
          </tr>
          <tr>
            <td>$(p.nodeB)</td>
            <td>$(compactstr(p.net[p.nodeB]))</td>
            <td>$(nsubsystems(p.net[p.nodeB]))</td>
            <td>$(_qtcp_count(counts_b, LinkLevelRequest))</td>
            <td>$(_qtcp_count(counts_b, LinkLevelReply))</td>
            <td>$(_qtcp_count(counts_b, LinkLevelReplyAtHop))</td>
          </tr>
        </tbody>
      </table>
    </div>
    """)
end
