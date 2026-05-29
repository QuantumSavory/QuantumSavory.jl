module QuantumSavoryHDF5

import QuantumSavory
using QuantumSavory.ProtocolZoo
import FileIO, HDF5

function make_enum_type_uint8(enum_dict::Dict)
    hdf5_enum_types = HDF5.Datatype(HDF5.API.h5t_create(HDF5.API.H5T_ENUM, sizeof(UInt8)))

    for (name, val) in enum_dict
        HDF5.API.h5t_enum_insert(hdf5_enum_types, name, Ref(val))
    end

    return hdf5_enum_types
end

function enum_to_dict(enum::DataType)
    return Dict(string(k) => k for k in instances(enum))
end

format_version::UInt64 = 1
format_version_minor::UInt64 = 1
quantumsavory_format_version::UInt64 = 1

@enum reference_state_types::UInt8 begin
    bell_pair = 0
end

@enum log_format_types::UInt8 begin
    fidelity            = 0
    state_vector        = 1
    werner_vector       = 2
    density_matrix      = 3
    pauli_observables   = 4
end

@enum simulation_mode::UInt8 begin
    repeated_single_shot = 0
    stateful = 1
end

reference_state_types_enum_dict = enum_to_dict(reference_state_types)
log_format_types_enum_dict = enum_to_dict(log_format_types)
simulation_mode_enum_dict = enum_to_dict(simulation_mode)

mandatory_qnet_group_attribute_keys = ["reference_state", "log_format", "simulation_mode"]
mandatory_metadata_group_attribute_keys = ["description", "simulator"]

function FileIO.save(save_file::FileIO.File{FileIO.DataFormat{:HDF5},String}, prot::EntanglementConsumer; metadata::Union{Dict{String,Any},Nothing} = nothing)
    HDF5.h5open(save_file.filename, "w") do file
        reference_state = bell_pair
        log_format = pauli_observables
        simulation_mode = stateful

        if !isnothing(metadata)
            for mandatory_key in mandatory_qnet_group_attribute_keys
                if !haskey(metadata, mandatory_key)
                    throw(ArgumentError("Metadata must contain the following keys: " * string(mandatory_qnet_group_attribute_keys) * "."))
                end
            end

            for mandatory_key in mandatory_metadata_group_attribute_keys
                if !haskey(metadata, mandatory_key)
                    throw(ArgumentError("Metadata must contain the following keys: " * string(mandatory_metadata_group_attribute_keys) * "."))
                end
            end

            reference_state = reference_state_types_enum_dict[metadata["reference_state"]]
            log_format = log_format_types_enum_dict[metadata["log_format"]]
            simulation_mode = simulation_mode_enum_dict[metadata["simulation_mode"]]
        else
            throw(ArgumentError("Metadata must contain the following attribute keys: " * string(mandatory_qnet_group_attribute_keys)))
            throw(ArgumentError("Metadata must contain the following metadata keys: " * string(mandatory_metadata_group_attribute_keys)))
        end

        qnet_group = HDF5.create_group(file, "qnet")
        metadata_group = HDF5.create_group(qnet_group, "metadata")
        simulation_log_group = HDF5.create_group(qnet_group, "simulation_log")
        quantumsavory_group = HDF5.create_group(metadata_group, "quantumsavory")
        user_optional_group = HDF5.create_group(metadata_group, "user_optional")

        ref_dt = make_enum_type_uint8(reference_state_types_enum_dict)
        log_dt = make_enum_type_uint8(log_format_types_enum_dict)
        sim_dt = make_enum_type_uint8(simulation_mode_enum_dict)
        scalar_space = HDF5.Dataspace(HDF5.API.h5s_create(HDF5.API.H5S_SCALAR))

        attr_ref = HDF5.create_attribute(qnet_group, "reference_state", ref_dt, scalar_space)
        attr_log = HDF5.create_attribute(qnet_group, "log_format", log_dt, scalar_space)
        attr_sim = HDF5.create_attribute(qnet_group, "simulation_mode", sim_dt, scalar_space)

        HDF5.write_attribute(attr_ref, ref_dt, UInt8(reference_state))
        HDF5.write_attribute(attr_log, log_dt, UInt8(log_format))
        HDF5.write_attribute(attr_sim, sim_dt, UInt8(simulation_mode))

        HDF5.write_attribute(qnet_group, "format_version", format_version)
        HDF5.write_attribute(qnet_group, "format_version_minor", format_version_minor)
        HDF5.write_attribute(metadata_group, "description", metadata["description"])
        HDF5.write_attribute(metadata_group, "simulator", metadata["simulator"])
        HDF5.write_attribute(quantumsavory_group, "quantumsavory_format_version", quantumsavory_format_version)

        if !isempty(prot._log)
            HDF5.write(simulation_log_group, "time", [getfield(log, :t) for log in prot._log])

            if log_format == pauli_observables
                state = zeros(Float64, 2, length(prot._log))
                state[1,:] = [getfield(log, :obs1) for log in prot._log]
                state[2,:] = [getfield(log, :obs2) for log in prot._log]
                HDF5.write(simulation_log_group, "state", state)
            else
                display([log_format, pauli_observables])
                throw(ArgumentError("Only `pauli_observables` log format is currently supported for saving."))
            end
        end

        for metadata_key in setdiff(keys(metadata), mandatory_qnet_group_attribute_keys, mandatory_metadata_group_attribute_keys)
            HDF5.write_attribute(user_optional_group, metadata_key, metadata[metadata_key])
        end
    end
end

end

