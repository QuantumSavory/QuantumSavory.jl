module QuantumSavoryCSV

import QuantumSavory
using QuantumSavory.ProtocolZoo
import FileIO, CSV, DataFrames

function QuantumSavory.ProtocolZoo._save_entanglement_consumer_log(save_file::FileIO.File{FileIO.DataFormat{:CSV},String}, prot::EntanglementConsumer)
    if !isempty(prot._log)
        CSV.write(save_file, DataFrames.DataFrame(prot._log, ["t", "obs1", "obs2"]))
    end
end

end
