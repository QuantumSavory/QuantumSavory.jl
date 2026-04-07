module QuantumSavoryHDF5

import QuantumSavory
using QuantumSavory.ProtocolZoo
import FileIO, HDF5

function QuantumSavory.ProtocolZoo._save_entanglement_consumer_log(save_file::FileIO.File{FileIO.DataFormat{:HDF5},String}, prot::EntanglementConsumer)
    HDF5.h5open(save_file.filename, "w") do file
        write(file, "t", [log.t for log in prot._log])
        write(file, "obs1", [log.obs1 for log in prot._log])
        write(file, "obs2", [log.obs2 for log in prot._log])

        if !isnothing(prot._metadata)
            metadata_keys = collect(keys(prot._metadata))
            metadata_values = Vector{String}()
            for key in metadata_keys
                push!(metadata_values, string(prot._metadata[key]))
            end

            write(file, "metadata_keys", metadata_keys)
            write(file, "metadata_values", metadata_values)
        end
    end
end

end

