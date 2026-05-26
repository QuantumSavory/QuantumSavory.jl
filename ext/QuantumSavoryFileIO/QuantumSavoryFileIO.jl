module QuantumSavoryFileIO

import QuantumSavory
using QuantumSavory.ProtocolZoo
import FileIO

function _set_metadata_default_values(metadata::Dict{String,Any})
    if !haskey(metadata, "reference_state")
        metadata["reference_state"] = "bell_pair"
    end

    if !haskey(metadata, "log_format")
        metadata["log_format"] = "pauli_observables"
    end

    if !haskey(metadata, "simulation_mode")
        metadata["simulation_mode"] = "stateful"
    end

    if !haskey(metadata, "description")
        metadata["description"] = ""
    end

    metadata["simulator"] = "QuantumSavory.jl"

    return metadata
end

function FileIO.save(file_name::String, prot::EntanglementConsumer; metadata::Union{Dict{String,Any}, NamedTuple, Nothing} = nothing)
    if isnothing(metadata)
        metadata = Dict{String,Any}()
    elseif isa(metadata, NamedTuple)
        metadata = Dict(string(k) => v for (k, v) in pairs(metadata))
    end
    
    metadata = _set_metadata_default_values(metadata)
    FileIO.save(FileIO.query(file_name), prot; metadata)
end

end

