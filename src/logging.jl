"""
Stable domain groups used by QuantumSavory log records.

These symbols populate Julia's standard log-record `group` field. Custom loggers can
filter on the group in `Logging.shouldlog` before a message or its metadata is built.
"""
const LOG_GROUPS = (
    backend = :backend,
    network = :network,
    protocol = :protocol,
    simulation = :simulation,
    visualization = :visualization,
)
