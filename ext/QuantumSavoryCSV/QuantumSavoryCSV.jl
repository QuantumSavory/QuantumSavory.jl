module QuantumSavoryCSV

import QuantumSavory
using QuantumSavory.ProtocolZoo
import FileIO, CSV, DataFrames

function FileIO.save(save_file::FileIO.File{FileIO.DataFormat{:CSV},String}, prot::EntanglementConsumer; metadata::Union{Dict{String,Any},Nothing} = nothing)
    if !isempty(prot._log)
        CSV.write(save_file, DataFrames.DataFrame(prot._log, ["t", "obs1", "obs2"]))
    end
end

end
