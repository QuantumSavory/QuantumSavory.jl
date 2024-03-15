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
@test query(r, :symbol1, 4, ❓) == (slot=r[2], depth=1, tag=tag_types.SymbolIntInt(:symbol1, 4, 5))
@test query(r, :symbol1, 4, 5) == (slot=r[2], depth=1, tag=tag_types.SymbolIntInt(:symbol1, 4, 5))
@test query(r, :symbol1, ❓, ❓) == (slot=r[1], depth=1, tag=tag_types.SymbolIntInt(:symbol1, 2, 3))
@test query(r, :symbol2, ❓, ❓) == nothing
@test query(r, Int, 4, 5) == (slot=r[5], depth=1, tag=tag_types.TypeIntInt(Int, 4, 5))
@test query(r, Float32, 4, 5) == nothing
@test query(r, Int, 4, >(5)) == nothing
@test query(r, Int, 4, <(6)) == (slot=r[5], depth=1, tag=tag_types.TypeIntInt(Int, 4, 5))

@test queryall(r, :symbol1, ❓, ❓) == [(slot=r[1], depth=1, tag=tag_types.SymbolIntInt(:symbol1, 2, 3)), (slot=r[2], depth=1, tag=tag_types.SymbolIntInt(:symbol1, 4, 5))]
@test isempty(queryall(r, :symbol2, ❓, ❓))

@test query(r[2], Tag(:symbol1, 4, 5)) == (depth=1, tag=Tag(:symbol1, 4, 5))
@test queryall(r[2], Tag(:symbol1, 4, 5)) == [(depth=1, tag=Tag(:symbol1, 4, 5))]
@test query(r[2], :symbol1, 4, 5) == (depth=1, tag=Tag(:symbol1, 4, 5))
@test queryall(r[2], :symbol1, 4, 5) == [(depth=1, tag=Tag(:symbol1, 4, 5))]

@test query(r[2], :symbol1, 4, ❓) == (depth=1, tag=Tag(:symbol1, 4, 5))
@test queryall(r[2], :symbol1, 4, ❓) == [(depth=1, tag=Tag(:symbol1, 4, 5))]

@test querydelete!(r[2], :symbol1, 4, ❓) == Tag(:symbol1, 4, 5)
@test querydelete!(r[2], :symbol1, 4, ❓) === nothing


# tests for fifo and filo order queries (default is filo)
# for RegRefs

reg = Register(5)
tag!(reg[3], EntanglementCounterpart, 1, 10)
tag!(reg[3], EntanglementCounterpart, 2, 20)
tag!(reg[3], EntanglementCounterpart, 3, 30)
tag!(reg[3], EntanglementCounterpart, 2, 20)
tag!(reg[3], EntanglementCounterpart, 1, 10)
tag!(reg[3], EntanglementCounterpart, 6, 60)
tag!(reg[3], EntanglementCounterpart, 2, 20)
tag!(reg[3], EntanglementCounterpart, 1, 10)

@test query(reg[3], EntanglementCounterpart, 1, 11) === nothing
@test query(reg[3], EntanglementCounterpart, 1, 10) == (depth = 8, tag = Tag(EntanglementCounterpart,1,10))
@test query(reg[3], EntanglementCounterpart, 1, 10, Val(false); filo=false) == (depth = 1, tag = Tag(EntanglementCounterpart,1,10))
@test query(reg[3], EntanglementCounterpart, 1, 10, Val(false); filo=true) == (depth = 8, tag = Tag(EntanglementCounterpart,1,10))

@test query(reg[3], EntanglementCounterpart, 2, ❓) == (depth = 7, tag = Tag(EntanglementCounterpart,2,20))
@test query(reg[3], EntanglementCounterpart, 2, ❓, Val(false); filo=false) == (depth = 2, tag = Tag(EntanglementCounterpart,2,20))
@test query(reg[3], EntanglementCounterpart, 2, ❓, Val(false); filo=true) == (depth = 7, tag = Tag(EntanglementCounterpart,2,20))

@test queryall(reg, EntanglementCounterpart, 1, 11) == []
@test queryall(reg[3], EntanglementCounterpart, 1, 10) == [(depth = d, tag = Tag(EntanglementCounterpart,1,10)) for d in (8,5,1)]
@test queryall(reg[3], EntanglementCounterpart, 1, 10; filo=false) == [(depth = d, tag = Tag(EntanglementCounterpart,1,10)) for d in (1,5,8)]
@test queryall(reg[3], EntanglementCounterpart, 1, 10; filo=true) == [(depth = d, tag = Tag(EntanglementCounterpart,1,10)) for d in (8,5,1)]

@test queryall(reg[3], EntanglementCounterpart, 2, ❓) == [(depth = d, tag = Tag(EntanglementCounterpart,2,20)) for d in (7,4,2)]
@test queryall(reg[3], EntanglementCounterpart, 2, ❓; filo=false) == [(depth = d, tag = Tag(EntanglementCounterpart,2,20)) for d in (2,4,7)]
@test queryall(reg[3], EntanglementCounterpart, 2, ❓; filo=true) == [(depth = d, tag = Tag(EntanglementCounterpart,2,20)) for d in (7,4,2)]

# tests for fifo and filo order queries (default is filo)
# for RegRefs

reg = Register(5)
for i in 2:4
    tag!(reg[i], EntanglementCounterpart, 1,  10+i)
    tag!(reg[i], EntanglementCounterpart, 2,  20+i)
    tag!(reg[i], EntanglementCounterpart, 3,  30+i)
    tag!(reg[i], EntanglementCounterpart, 2, 120+i)
    tag!(reg[i], EntanglementCounterpart, 1, 110+i)
    tag!(reg[i], EntanglementCounterpart, 6,  60+i)
    tag!(reg[i], EntanglementCounterpart, 2,  20+i)
    tag!(reg[i], EntanglementCounterpart, 1, 310+i)
end

@test query(reg, EntanglementCounterpart, 1, 10) === nothing
@test query(reg, EntanglementCounterpart, 1, 12) == (slot = reg[2], depth = 1, tag = Tag(EntanglementCounterpart,1,12))
@test query(reg, EntanglementCounterpart, 1, 12) == query(reg, EntanglementCounterpart, ==(1), ==(12))
@test query(reg, Tag(EntanglementCounterpart, 1, 10)) === nothing
@test query(reg, Tag(EntanglementCounterpart, 1, 12)) == (slot = reg[2], depth = 1, tag = Tag(EntanglementCounterpart,1,12))
@test query(reg, EntanglementCounterpart, 1, 12, Val(false); filo=false) == (slot = reg[2], depth = 1, tag = Tag(EntanglementCounterpart,1,12))
@test query(reg, EntanglementCounterpart, 1, 12, Val(false); filo=true) == (slot = reg[2], depth = 1, tag = Tag(EntanglementCounterpart,1,12))
@test query(reg, EntanglementCounterpart, 1, 12, Val(false); filo=false) == query(reg, EntanglementCounterpart, 1, ==(12), Val(false); filo=false)
@test query(reg, EntanglementCounterpart, 1, 12, Val(false); filo=true) == query(reg, EntanglementCounterpart, 1, ==(12), Val(false); filo=true)
@test query(reg, EntanglementCounterpart, 1, ❓, Val(false); filo=false) == (slot = reg[2], depth = 1, tag = Tag(EntanglementCounterpart,1,12))
@test query(reg, EntanglementCounterpart, 1, ❓, Val(false); filo=true) == (slot = reg[2], depth = 8, tag = Tag(EntanglementCounterpart,1,312))

@test queryall(reg, EntanglementCounterpart, 1, ❓) == [(slot = reg[i], depth = d, tag = Tag(EntanglementCounterpart,1,j+i)) for i in 2:4 for (d,j) in ((8,310),(5,110),(1,10))]
@test queryall(reg, EntanglementCounterpart, 1, ❓; filo=true) == [(slot = reg[i], depth = d, tag = Tag(EntanglementCounterpart,1,j+i)) for i in 2:4 for (d,j) in ((8,310),(5,110),(1,10))]
@test queryall(reg, EntanglementCounterpart, 1, ❓; filo=false) == [(slot = reg[i], depth = d, tag = Tag(EntanglementCounterpart,1,j+i)) for i in 2:4 for (d,j) in reverse(((8,310),(5,110),(1,10)))]

@test query(reg, EntanglementCounterpart, 2, 22) == (slot = reg[2], depth = 7, tag = Tag(EntanglementCounterpart,2,22))
@test queryall(reg, EntanglementCounterpart, 2, 22) == [(slot = reg[2], depth = 7, tag = Tag(EntanglementCounterpart,2,22)), (slot = reg[2], depth = 2, tag = Tag(EntanglementCounterpart,2,22))]
@test queryall(reg, Tag(EntanglementCounterpart, 2, 22)) == [(slot = reg[2], depth = 7, tag = Tag(EntanglementCounterpart,2,22)), (slot = reg[2], depth = 2, tag = Tag(EntanglementCounterpart,2,22))]
@test queryall(reg, EntanglementCounterpart, 2, 22) == queryall(reg, EntanglementCounterpart, ==(2), ==(22)) == queryall(reg, Tag(EntanglementCounterpart, 2, 22))
@test queryall(reg, Tag(EntanglementCounterpart, 2, 22); filo=false) == reverse([(slot = reg[2], depth = 7, tag = Tag(EntanglementCounterpart,2,22)), (slot = reg[2], depth = 2, tag = Tag(EntanglementCounterpart,2,22))])
@test queryall(reg, EntanglementCounterpart, 2, 22; filo=false) == queryall(reg, EntanglementCounterpart, ==(2), ==(22); filo=false) == queryall(reg, Tag(EntanglementCounterpart, 2, 22); filo=false)
