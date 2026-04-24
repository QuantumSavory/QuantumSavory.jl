module QuantumSavoryHDF5

import QuantumSavory
using QuantumSavory.ProtocolZoo
import FileIO, HDF5

function FileIO.save(save_file::FileIO.File{FileIO.DataFormat{:HDF5},String}, prot::EntanglementConsumer; metadata::Union{Dict{String,Any},Nothing} = nothing)
    HDF5.h5open(save_file.filename, "w") do file
        write(file, "t", [log.t for log in prot._log])
        write(file, "obs1", [log.obs1 for log in prot._log])
        write(file, "obs2", [log.obs2 for log in prot._log])

        if !isnothing(metadata)
            metadata_keys = collect(keys(metadata))
            metadata_values = Vector{String}()
            for key in metadata_keys
                push!(metadata_values, string(metadata[key]))
            end

            write(file, "metadata_keys", metadata_keys)
            write(file, "metadata_values", metadata_values)
        end
    end
end

end

