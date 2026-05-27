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

function Base.show(io::IO, m::MIME"text/html", p::GHZProjectionProt)
    delivered = length(p._log)
    last_id = delivered > 0 ? last(p._log).ghz_id : p.first_ghz_id - 1
    print(io,
    """
    <div class="quantumsavory_show quantumsavory_protocol quantumsavory_protocol_ghz_projection">
    <h1><code class="quantumsavory_typename quantumsavory_protocol_typename">GHZProjectionProt</code> protocol</h1>
    <address>hub $(compactstr(p.net[p.hub])) to members $(join(p.members, ", "))</address>
    <dl>
    <dt>Delivered GHZ states</dt>
    <dd>$(delivered)</dd>
    <dt>Last GHZ id</dt>
    <dd>$(last_id)</dd>
    </dl>
    <h2>Log</h2>
    $(pretty_table(String, p._log, column_labels=["Time", "GHZ id", "Hub slots", "Member nodes", "Member slots", "X outcome", "Z outcomes"], backend=:html, maximum_number_of_rows=25))
    </div>
    """)
end

function Base.show(io::IO, m::MIME"text/html", p::GHZReceiverProt)
    received = length(p._log)
    print(io,
    """
    <div class="quantumsavory_show quantumsavory_protocol quantumsavory_protocol_ghz_receiver">
    <h1><code class="quantumsavory_typename quantumsavory_protocol_typename">GHZReceiverProt</code> protocol</h1>
    <address>on $(compactstr(p.net[p.node]))</address>
    <dl>
    <dt>Received GHZ member announcements</dt>
    <dd>$(received)</dd>
    </dl>
    <h2>Log</h2>
    $(pretty_table(String, p._log, column_labels=["Time", "GHZ id", "Member slot", "Member index", "Member count"], backend=:html, maximum_number_of_rows=25))
    </div>
    """)
end
