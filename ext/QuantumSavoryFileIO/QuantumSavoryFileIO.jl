module QuantumSavoryFileIO

import QuantumSavory
using QuantumSavory.ProtocolZoo
import FileIO

function FileIO.save(file_name::String, prot::EntanglementConsumer; metadata::Union{Dict{String,Any},Nothing} = nothing)
    FileIO.save(FileIO.query(file_name), prot; metadata)
end

end

