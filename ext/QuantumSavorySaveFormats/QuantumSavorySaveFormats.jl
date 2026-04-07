module QuantumSavorySaveFormats

import QuantumSavory
using QuantumSavory.ProtocolZoo
import FileIO

function QuantumSavory.ProtocolZoo._save_entanglement_consumer_log(file_name::String, prot::EntanglementConsumer)
    QuantumSavory.ProtocolZoo._save_entanglement_consumer_log(FileIO.query(file_name), prot)
end

end