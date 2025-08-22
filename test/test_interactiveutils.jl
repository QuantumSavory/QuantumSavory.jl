@testitem "InteractiveUtils" begin
using QuantumSavory
using QuantumSavory.ProtocolZoo
using InteractiveUtils

bgs = QuantumSavory.available_background_types()
QuantumSavory.constructor_metadata.(bgs)
prots = QuantumSavory.ProtocolZoo.available_protocol_types()
QuantumSavory.constructor_metadata.(prots)


end
