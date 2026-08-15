using PrettyTables: pretty_table
using Statistics: mean, median
import QuantumSavory: compactstr

"""Extract timing samples from a `LinkController` log."""
function _linkcontroller_samples(prot::LinkController)
    arrival_times_a = sort!(
        [entry.arrival_time for entry in prot._log if entry.originator_node == prot.nodeA]
    )
    arrival_times_b = sort!(
        [entry.arrival_time for entry in prot._log if entry.originator_node == prot.nodeB]
    )
    sojourn_times = Float64[
        entry.sojourn_time::Float64 for entry in prot._log
        if !isnothing(entry.sojourn_time)
    ]
    return (;
        arrival_times_a,
        arrival_times_b,
        interarrival_times_a=diff(arrival_times_a),
        interarrival_times_b=diff(arrival_times_b),
        sojourn_times,
    )
end

"""Summarize timing samples with their mean and median."""
function _sample_summary(samples)
    isempty(samples) && return (mean=nothing, median=nothing)
    return (mean=mean(samples), median=median(samples))
end

"""Format an optional timing statistic for display."""
_show_sample(value) =
    isnothing(value) ? "No samples" : string(round(value; sigdigits=5))

function Base.show(io::IO, m::MIME"text/html", prot::LinkController)
    samples = _linkcontroller_samples(prot)
    interarrival_a = _sample_summary(samples.interarrival_times_a)
    interarrival_b = _sample_summary(samples.interarrival_times_b)
    sojourn = _sample_summary(samples.sojourn_times)
    label_a = compactstr(prot.net[prot.nodeA])
    label_b = compactstr(prot.net[prot.nodeB])
    pending_requests = length(prot._log) - length(samples.sojourn_times)

    print(io,
    """
    <div class="quantumsavory_show quantumsavory_protocol quantumsavory_protocol_link_controller">
      <h1><code class="quantumsavory_typename quantumsavory_protocol_typename">LinkController</code> protocol</h1>
      <address>on <b>$(label_a)</b> and <b>$(label_b)</b></address>
      <h2>Entanglement generation</h2>
    """)
    show(io, m, _link_entangler(prot))
    print(io,
    """
      <h2>Link-level request interarrival times</h2>
      <h3>$(label_a)</h3>
      <dl>
        <dt>Requests</dt>
        <dd>$(length(samples.arrival_times_a))</dd>
        <dt>Mean interarrival time</dt>
        <dd>$(_show_sample(interarrival_a.mean))</dd>
        <dt>Median interarrival time</dt>
        <dd>$(_show_sample(interarrival_a.median))</dd>
      </dl>
      <h3>$(label_b)</h3>
      <dl>
        <dt>Requests</dt>
        <dd>$(length(samples.arrival_times_b))</dd>
        <dt>Mean interarrival time</dt>
        <dd>$(_show_sample(interarrival_b.mean))</dd>
        <dt>Median interarrival time</dt>
        <dd>$(_show_sample(interarrival_b.median))</dd>
      </dl>
      <h2>Link-level request sojourn times</h2>
      <dl>
        <dt>Completed requests</dt>
        <dd>$(length(samples.sojourn_times))</dd>
        <dt>Pending requests</dt>
        <dd>$(pending_requests)</dd>
        <dt>Mean sojourn time</dt>
        <dd>$(_show_sample(sojourn.mean))</dd>
        <dt>Median sojourn time</dt>
        <dd>$(_show_sample(sojourn.median))</dd>
      </dl>
      <h2>Request log</h2>
      $(pretty_table(
          String,
          prot._log;
          column_labels=["Originator node", "Arrival time", "Sojourn time"],
          backend=:html,
          maximum_number_of_rows=25,
      ))
    </div>
    """)
end

"""Return per-flow QDatagram statistics for `prot`."""
function _network_node_controller_statistics(prot::NetworkNodeController)
    flow_ids = sort!(unique(event.flow_id for event in prot._log))
    return map(flow_ids) do flow_id
        events = filter(event -> event.flow_id == flow_id, prot._log)
        processed = filter(event -> event.processed, events)
        average_sojourn = isempty(processed) ? "—" : sum(event.sojourn for event in processed) / length(processed)
        return (
            flow_id=flow_id,
            backlog=sum(event.processed ? -1 : 1 for event in events),
            average_sojourn=average_sojourn,
            processed=length(processed),
        )
    end
end

function Base.show(io::IO, ::MIME"text/html", prot::NetworkNodeController)
    node_label = QuantumSavory._html_escape_text(QuantumSavory.compactstr(prot.net[prot.node]))
    statistics = _network_node_controller_statistics(prot)
    content = if isempty(statistics)
        "<p>No QDatagrams observed.</p>"
    else
        pretty_table(
            String,
            statistics;
            column_labels=["Flow ID", "Current backlog", "Average sojourn time", "Processed QDatagrams"],
            backend=:html,
        )
    end
    print(io,
    """
    <div class="quantumsavory_show quantumsavory_protocol quantumsavory_protocol_network_node_controller">
      <h1><code class="quantumsavory_typename quantumsavory_protocol_typename">NetworkNodeController</code> protocol</h1>
      <address>on <b>$(node_label)</b></address>
      <h2>Per-flow QDatagram statistics</h2>
      $(content)
    </div>
    """)
end
