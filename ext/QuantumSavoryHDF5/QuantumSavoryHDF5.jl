module QuantumSavoryHDF5

import QuantumSavory
using QuantumSavory.ProtocolZoo
import FileIO, HDF5

function FileIO.save(save_file::FileIO.File{FileIO.DataFormat{:HDF5},String}, prot::EntanglementConsumer; metadata::Union{Dict{String,Any},Nothing} = nothing)
    HDF5.h5open(save_file.filename, "w") do file
        if !isnothing(metadata)
            for metadata_key in keys(metadata)
                write(file, string(metadata_key), string(metadata[metadata_key]))
            end
        end

        if !isempty(prot._log)
            for property_name in propertynames(prot._log[1])
                write(file, string(property_name), [getfield(log, property_name) for log in prot._log])
            end
        end
    end
end

end

