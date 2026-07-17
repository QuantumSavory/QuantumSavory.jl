"""
Stable log groups emitted by QuantumSavory.

Pass one of these symbols through the logging macro's special `_group` keyword
to let loggers reject a family of records before the message and metadata are
constructed.
"""
const LOG_GROUPS = (
    backend = :backend,
    simulation = :simulation,
    protocol = :protocol,
    network = :network,
    visualization = :visualization,
)

"""
    simulation_log_context(sim::Simulation)

Return the structured logging context for `sim`.

The result contains the current simulated time and the active ConcurrentSim
process identifier. `sim_process_id` is `nothing` when called outside a running
process.
"""
function simulation_log_context(sim::Simulation)
    process = active_process(sim)
    sim_process_id = isnothing(process) ? nothing : process.bev.id
    return (; sim_time=Float64(now(sim)), sim_process_id)
end

@inline function _message_type(tag)
    head = tag[1]
    return head isa Symbol ? head : nameof(head)
end
