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
process. This is an internal helper for repository-owned logging; its fields are
not a stable public schema. Use [`LOG_GROUPS`](@ref) for stable coarse filtering.
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
