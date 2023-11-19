using QuantumSavory
using QuantumSavory: tag_types
using Test

r = Register(10)
tag!(r[1], :symbol1, 2, 3)
tag!(r[2], :symbol1, 4, 5)
tag!(r[5], Int, 4, 5)

@test Tag(:symbol1, 2, 3) == tag_types.SymbolIntInt(:symbol1, 2, 3)
@test query(r, :symbol1, 4, ❓) == (slot=r[2], tag=tag_types.SymbolIntInt(:symbol1, 4, 5))
@test query(r, :symbol1, 4, 5) == (slot=r[2], tag=tag_types.SymbolIntInt(:symbol1, 4, 5))
@test query(r, :symbol1, ❓, ❓) == (slot=r[1], tag=tag_types.SymbolIntInt(:symbol1, 2, 3))
@test query(r, :symbol2, ❓, ❓) == nothing
@test query(r, Int, 4, 5) == (slot=r[5], tag=tag_types.TypeIntInt(Int, 4, 5))
@test query(r, Float32, 4, 5) == nothing
@test query(r, Int, 4, >(5)) == nothing
@test query(r, Int, 4, <(6)) == (slot=r[5], tag=tag_types.TypeIntInt(Int, 4, 5))
