"""
$TYPEDEF

A struct representing the metadata for an entanglement consumer log file.

$FIELDS
"""
@kwdef struct EntanglementConsumerLogMetadata
    """A description of the simulation or experiment."""
    description::String = ""
    """The name of the simulator used for the simulation or experiment."""
    simulator::String = ""
    """A dictionary containing additional metadata related to the QuantumSavory simulation or experiment."""
    quantumsavory_metadata::Dict{String,Any} = Dict{String,Any}()
end

"""
$TYPEDEF

A struct representing the simulation log for an entanglement consumer log file.

$FIELDS
"""
@kwdef struct EntanglementConsumerLogSimulationLog
    """A vector of time points corresponding to the logged data."""
    time::Vector{Float64} = zeros(Float64,0)
    """A matrix containing the logged data, where each row corresponds to a time point and each column corresponds to a different observable."""
    state::Matrix{Float64} = zeros(Float64,0,0)
end

"""
$TYPEDEF

A struct representing an entanglement consumer log file.

$FIELDS
"""
@kwdef struct EntanglementConsumerLog
    """The version of the QuantumSavory file format used for this log file."""
    format_version::UInt64 = UInt64(0)
    """The minor version of the QuantumSavory file format used for this log file."""
    format_version_minor::UInt64 = UInt64(0)
    """The format of the log data (e.g., "pauli_observables", "state_vector")."""
    log_format::String = ""
    """The reference state used in the simulation (e.g., "bell_pair")."""
    reference_state::String = ""
    """The simulation mode used in the simulation (e.g., "stateful", "repeated_single_shot")."""
    simulation_mode::String = ""
    """The metadata associated with the entanglement consumer log file."""
    metadata::EntanglementConsumerLogMetadata = EntanglementConsumerLogMetadata()
    """The simulation log data for the entanglement consumer log file."""
    simulation_log::EntanglementConsumerLogSimulationLog = EntanglementConsumerLogSimulationLog()
end

function EntanglementConsumerLog end
