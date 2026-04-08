module QuantumSavoryFileIO

import QuantumSavory
using QuantumSavory.ProtocolZoo
import FileIO

function _print_load_error(_::FileIO.File{FileIO.DataFormat{:HDF5},String})
    if !isdefined(Main, :HDF5)
        @error "Attempted to save an EntanglementConsumer log to a HDF5 file, but HDF5.jl is not loaded. Please load HDF5.jl to enable saving logs to HDF5 files."
    end
end

function _print_load_error(_::FileIO.File{FileIO.DataFormat{:CSV},String})
    if !isdefined(Main, :CSV)
        @error "Attempted to save an EntanglementConsumer log to a CSV file, but CSV.jl is not loaded. Please load CSV.jl to enable saving logs to CSV files."
    end

    if !isdefined(Main, :DataFrames)
        @error "Attempted to save an EntanglementConsumer log to a CSV file, but DataFrames.jl is not loaded. Please load DataFrames.jl to enable saving logs to CSV files."
    end
end

function _print_load_error(_::FileIO.File)
    @error "Attempted to save an EntanglementConsumer log to an unsupported file format. Supported formats are .h5 (HDF5) and .csv (CSV)."
end

function QuantumSavory.ProtocolZoo._save_entanglement_consumer_log(file_name::String, prot::EntanglementConsumer)
    try
        QuantumSavory.ProtocolZoo._save_entanglement_consumer_log(FileIO.query(file_name), prot)
    catch
        _print_load_error(FileIO.query(file_name))
    end
end

end

