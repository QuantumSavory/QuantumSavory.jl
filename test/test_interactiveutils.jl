@testitem "InteractiveUtils" begin
using QuantumSavory
using QuantumSavory.ProtocolZoo
using InteractiveUtils
using REPL

bgs = QuantumSavory.available_background_types()
QuantumSavory.constructor_metadata.([bg.type for bg in bgs])
prots = QuantumSavory.ProtocolZoo.available_protocol_types()
QuantumSavory.constructor_metadata.([p.type for p in prots])
slots = QuantumSavory.available_slot_types()
@test length(bgs)>1
@test length(prots)>1
@test length(slots)>1

end
