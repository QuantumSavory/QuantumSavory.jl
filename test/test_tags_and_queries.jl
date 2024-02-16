using QuantumSavory
using QuantumSavory: tag_types
using QuantumSavory.ProtocolZoo: EntanglementCounterpart
using Test

@test tag_types.SymbolIntInt(:symbol1, 4, 5) == Tag(:symbol1, 4, 5)

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

@test queryall(r, :symbol1, ❓, ❓) == [(slot=r[1], tag=tag_types.SymbolIntInt(:symbol1, 2, 3)), (slot=r[2], tag=tag_types.SymbolIntInt(:symbol1, 4, 5))]
@test isempty(queryall(r, :symbol2, ❓, ❓))

@test query(r[2], Tag(:symbol1, 4, 5)) == (depth=1, tag=Tag(:symbol1, 4, 5))
@test queryall(r[2], Tag(:symbol1, 4, 5)) == [(depth=1, tag=Tag(:symbol1, 4, 5))]
@test query(r[2], :symbol1, 4, 5) == (depth=1, tag=Tag(:symbol1, 4, 5))
@test queryall(r[2], :symbol1, 4, 5) == [(depth=1, tag=Tag(:symbol1, 4, 5))]

@test query(r[2], :symbol1, 4, ❓) == (depth=1, tag=Tag(:symbol1, 4, 5))
@test queryall(r[2], :symbol1, 4, ❓) == [(depth=1, tag=Tag(:symbol1, 4, 5))]

@test querydelete!(r[2], :symbol1, 4, ❓) == Tag(:symbol1, 4, 5)
@test querydelete!(r[2], :symbol1, 4, ❓) === nothing


# tests for fifo and filo order queries
# for RegRefs
reg = Register(5)
tag!(reg[3], EntanglementCounterpart, 2, 3)
tag!(reg[3], EntanglementCounterpart, 5, 1)
tag!(reg[3], EntanglementCounterpart, 9, 3)
tag!(reg[3], EntanglementCounterpart, 4, 3)
tag!(reg[3], EntanglementCounterpart, 5, 1)
tag!(reg[3], EntanglementCounterpart, 1, 9)
tag!(reg[3], EntanglementCounterpart, 5, 1)

@test query(reg[3], EntanglementCounterpart, 5, 1) == (depth = 7, tag = Tag(EntanglementCounterpart, 5, 1))
@test queryall(reg[3], EntanglementCounterpart, 5, 1) == [(depth = 7, tag = Tag(EntanglementCounterpart, 5, 1)), (depth = 5, tag = Tag(EntanglementCounterpart, 5, 1)), (depth = 2, tag = Tag(EntanglementCounterpart, 5, 1))]
@test queryall(reg[3], EntanglementCounterpart, 5, 1; fifo=false) == [(depth = 2, tag = Tag(EntanglementCounterpart, 5, 1)), (depth = 5, tag = Tag(EntanglementCounterpart, 5, 1)), (depth = 7, tag = Tag(EntanglementCounterpart, 5, 1))]

# for Register

reg = Register(5)
tag!(reg[3], EntanglementCounterpart, 2, 3)
tag!(reg[3], EntanglementCounterpart, 5, 1)
tag!(reg[3], EntanglementCounterpart, 9, 3)
tag!(reg[3], EntanglementCounterpart, 4, 3)
tag!(reg[3], EntanglementCounterpart, 5, 1)
tag!(reg[3], EntanglementCounterpart, 1, 9)
tag!(reg[3], EntanglementCounterpart, 5, 1)

tag!(reg[4], EntanglementCounterpart, 5, 1)
tag!(reg[4], EntanglementCounterpart, 5, 1)
tag!(reg[4], EntanglementCounterpart, 9, 3)
tag!(reg[4], EntanglementCounterpart, 1, 9)
tag!(reg[4], EntanglementCounterpart, 4, 3)
tag!(reg[4], EntanglementCounterpart, 5, 1)
tag!(reg[4], EntanglementCounterpart, 2, 3)

tag!(reg[1], EntanglementCounterpart, 2, 3)
tag!(reg[1], EntanglementCounterpart, 5, 1)
tag!(reg[1], EntanglementCounterpart, 4, 3)
tag!(reg[1], EntanglementCounterpart, 5, 1)
tag!(reg[1], EntanglementCounterpart, 1, 9)
tag!(reg[1], EntanglementCounterpart, 5, 1)
tag!(reg[1], EntanglementCounterpart, 9, 3)

@test query(reg, EntanglementCounterpart, 5, 1) == (slot = reg[4], tag = Tag(EntanglementCounterpart, 5, 1))
@test queryall(reg, EntanglementCounterpart, 5, 1) == [(slot = reg[4], tag = Tag(EntanglementCounterpart, 5, 1)), (slot = reg[3], tag = Tag(EntanglementCounterpart, 5, 1)), (slot = reg[1], tag = Tag(EntanglementCounterpart, 5, 1))]
@test queryall(reg, Tag(EntanglementCounterpart, 5, 1); fifo=false) ==  [(slot = reg[1], tag = Tag(EntanglementCounterpart, 5, 1)), (slot = reg[3], tag = Tag(EntanglementCounterpart, 5, 1)), (slot = reg[4], tag = Tag(EntanglementCounterpart, 5, 1))]
