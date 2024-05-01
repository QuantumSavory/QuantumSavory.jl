using QuantumSavory
using QuantumSavory: tag_types
using QuantumSavory.ProtocolZoo: EntanglementCounterpart
using Test

@test tag_types.SymbolIntInt(:symbol1, 4, 5) == Tag(:symbol1, 4, 5)

r = Register(10)
tag!(r[1], :symbol1, 2, 3)
tag!(r[2], :symbol1, 4, 5)
tag!(r[3], :symbol1, 4, 1)
tag!(r[5], Int, 4, 5)

@test Tag(:symbol1, 2, 3) == tag_types.SymbolIntInt(:symbol1, 2, 3)
@test query(r, :symbol1, 4, ❓) == (slot=r[3], id=3, tag=tag_types.SymbolIntInt(:symbol1, 4, 1))
@test query(r, :symbol1, 4, 5) == (slot=r[2], id=2, tag=tag_types.SymbolIntInt(:symbol1, 4, 5))
@test query(r, :symbol1, ❓, ❓) == (slot=r[3], id=3, tag=tag_types.SymbolIntInt(:symbol1, 4, 1)) #returns latest tag in filo order
@test query(r, :symbol2, ❓, ❓) == nothing
@test query(r, Int, 4, 5) == (slot=r[5], id=4, tag=tag_types.TypeIntInt(Int, 4, 5))
@test query(r, Float32, 4, 5) == nothing
@test query(r, Int, 4, >(5)) == nothing
@test query(r, Int, 4, <(6)) == (slot=r[5], id=4, tag=tag_types.TypeIntInt(Int, 4, 5))

@test queryall(r, :symbol1, ❓, ❓) == [(slot=r[3], id=3, tag=tag_types.SymbolIntInt(:symbol1, 4, 1)), (slot=r[2], id=2, tag=tag_types.SymbolIntInt(:symbol1, 4, 5)), (slot=r[1], id=1, tag=tag_types.SymbolIntInt(:symbol1, 2, 3))] # filo by default
@test isempty(queryall(r, :symbol2, ❓, ❓))

@test query(r[2], Tag(:symbol1, 4, 5)) == (slot=r[2], id=2, tag=tag_types.SymbolIntInt(:symbol1, 4, 5))
@test queryall(r[2], Tag(:symbol1, 4, 5)) == [(slot=r[2], id=2, tag=Tag(:symbol1, 4, 5))]
@test query(r[2], :symbol1, 4, 5) == (slot=r[2], id=2, tag=Tag(:symbol1, 4, 5))
@test queryall(r[2], :symbol1, 4, 5) == [(slot=r[2], id=2, tag=Tag(:symbol1, 4, 5))]

@test query(r[2], :symbol1, 4, ❓) == (slot=r[2], id=2, tag=Tag(:symbol1, 4, 5))
@test queryall(r[2], :symbol1, 4, ❓) == [(slot=r[2], id=2, tag=Tag(:symbol1, 4, 5))]

@test querydelete!(r[2], :symbol1, 4, ❓) == (Tag(:symbol1, 4, 5), 2, nothing)
@test querydelete!(r[2], :symbol1, 4, ❓) === nothing
@test querydelete!(r[3], :symbol1, 4, ❓) == (Tag(:symbol1, 4, 1), 3, nothing)


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
@test query(reg[3], EntanglementCounterpart, 1, 10) == (slot = reg[3], id = 12, tag = Tag(EntanglementCounterpart,1,10))
@test query(reg[3], EntanglementCounterpart, 1, 10, Val(false); filo=false) == (slot = reg[3], id = 5, tag = Tag(EntanglementCounterpart,1,10))
@test query(reg[3], EntanglementCounterpart, 1, 10, Val(false); filo=true) == (slot = reg[3], id = 12, tag = Tag(EntanglementCounterpart,1,10))

@test query(reg[3], EntanglementCounterpart, 2, ❓) == (slot = reg[3], id = 11, tag = Tag(EntanglementCounterpart,2,20))
@test query(reg[3], EntanglementCounterpart, 2, ❓, Val(false); filo=false) == (slot = reg[3], id = 6, tag = Tag(EntanglementCounterpart,2,20))
@test query(reg[3], EntanglementCounterpart, 2, ❓, Val(false); filo=true) == (slot = reg[3], id = 11, tag = Tag(EntanglementCounterpart,2,20))

@test queryall(reg, EntanglementCounterpart, 1, 11) == []
@test queryall(reg[3], EntanglementCounterpart, 1, 10) == [(slot = reg[3], id = i, tag = Tag(EntanglementCounterpart,1,10)) for i in (12, 9, 5)]
@test queryall(reg[3], EntanglementCounterpart, 1, 10; filo=false) == [(slot = reg[3], id = i, tag = Tag(EntanglementCounterpart,1,10)) for i in (5, 9, 12)]
@test queryall(reg[3], EntanglementCounterpart, 1, 10; filo=true) == [(slot = reg[3], id = 12, tag = Tag(EntanglementCounterpart,1,10)) for i in (12, 9, 5)]

@test queryall(reg[3], EntanglementCounterpart, 2, ❓) == [(slot = reg[3], id = i, tag = Tag(EntanglementCounterpart,2,20)) for i in (11, 8, 6)]
@test queryall(reg[3], EntanglementCounterpart, 2, ❓; filo=false) == [(slot = reg[3], id = i, tag = Tag(EntanglementCounterpart,2,20)) for i in (6, 8, 11)]
@test queryall(reg[3], EntanglementCounterpart, 2, ❓; filo=true) == [(slot = reg[3], id = i, tag = Tag(EntanglementCounterpart,2,20)) for i in (11, 8, 6)]

# tests for fifo and filo order queries (default is filo)
# for Register

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
@test query(reg, EntanglementCounterpart, 1, 12) == (slot = reg[2], id = 13, tag = Tag(EntanglementCounterpart,1,12))
@test query(reg, EntanglementCounterpart, 1, 12) == query(reg, EntanglementCounterpart, ==(1), ==(12))
@test query(reg, Tag(EntanglementCounterpart, 1, 10)) === nothing
@test query(reg, Tag(EntanglementCounterpart, 1, 12)) == (slot = reg[2], id = 13, tag = Tag(EntanglementCounterpart,1,12))
@test query(reg, EntanglementCounterpart, 1, 12, Val(false); filo=false) == (slot = reg[2], id = 13, tag = Tag(EntanglementCounterpart,1,12))
@test query(reg, EntanglementCounterpart, 1, 12, Val(false); filo=true) == (slot = reg[2], id = 13, tag = Tag(EntanglementCounterpart,1,12))
@test query(reg, EntanglementCounterpart, 1, 12, Val(false); filo=false) == query(reg, EntanglementCounterpart, 1, ==(12), Val(false); filo=false)
@test query(reg, EntanglementCounterpart, 1, 12, Val(false); filo=true) == query(reg, EntanglementCounterpart, 1, ==(12), Val(false); filo=true)
@test query(reg, EntanglementCounterpart, 1, ❓, Val(false); filo=false) == (slot = reg[2], id = 13, tag = Tag(EntanglementCounterpart,1,12))
@test query(reg, EntanglementCounterpart, 1, ❓, Val(false); filo=true) == (slot = reg[4], id = 36, tag = Tag(EntanglementCounterpart,1,314))

@test queryall(reg, EntanglementCounterpart, 1, ❓) == [(slot = reg[4], id = 36, tag = Tag(EntanglementCounterpart, 1, 314)), (slot = reg[4], id = 33, tag = Tag(EntanglementCounterpart, 1, 114)), (slot = reg[4], id = 29, tag = Tag(EntanglementCounterpart, 1, 14)), (slot = reg[3], id = 28, tag = Tag(EntanglementCounterpart, 1, 313)), (slot = reg[3], id = 25, tag = Tag(EntanglementCounterpart, 1, 113)), (slot = reg[3], id = 21, tag = Tag(EntanglementCounterpart, 1, 13)), (slot = reg[2], id = 20, tag = Tag(EntanglementCounterpart, 1, 312)), (slot = reg[2], id = 17, tag = Tag(EntanglementCounterpart, 1, 112)), (slot = reg[2], id = 13, tag = Tag(EntanglementCounterpart, 1, 12))]
@test queryall(reg, EntanglementCounterpart, 1, ❓; filo=true) == [(slot = reg[4], id = 36, tag = Tag(EntanglementCounterpart, 1, 314)), (slot = reg[4], id = 33, tag = Tag(EntanglementCounterpart, 1, 114)), (slot = reg[4], id = 29, tag = Tag(EntanglementCounterpart, 1, 14)), (slot = reg[3], id = 28, tag = Tag(EntanglementCounterpart, 1, 313)), (slot = reg[3], id = 25, tag = Tag(EntanglementCounterpart, 1, 113)), (slot = reg[3], id = 21, tag = Tag(EntanglementCounterpart, 1, 13)), (slot = reg[2], id = 20, tag = Tag(EntanglementCounterpart, 1, 312)), (slot = reg[2], id = 17, tag = Tag(EntanglementCounterpart, 1, 112)), (slot = reg[2], id = 13, tag = Tag(EntanglementCounterpart, 1, 12))]
@test queryall(reg, EntanglementCounterpart, 1, ❓; filo=false) == reverse([(slot = reg[4], id = 36, tag = Tag(EntanglementCounterpart, 1, 314)), (slot = reg[4], id = 33, tag = Tag(EntanglementCounterpart, 1, 114)), (slot = reg[4], id = 29, tag = Tag(EntanglementCounterpart, 1, 14)), (slot = reg[3], id = 28, tag = Tag(EntanglementCounterpart, 1, 313)), (slot = reg[3], id = 25, tag = Tag(EntanglementCounterpart, 1, 113)), (slot = reg[3], id = 21, tag = Tag(EntanglementCounterpart, 1, 13)), (slot = reg[2], id = 20, tag = Tag(EntanglementCounterpart, 1, 312)), (slot = reg[2], id = 17, tag = Tag(EntanglementCounterpart, 1, 112)), (slot = reg[2], id = 13, tag = Tag(EntanglementCounterpart, 1, 12))])

@test query(reg, EntanglementCounterpart, 2, 22) == (slot = reg[2], id = 19, tag = Tag(EntanglementCounterpart,2,22))
@test queryall(reg, EntanglementCounterpart, 2, 22) == [(slot = reg[2], id = 19, tag = Tag(EntanglementCounterpart,2,22)), (slot = reg[2], id = 14, tag = Tag(EntanglementCounterpart,2,22))]
@test queryall(reg, Tag(EntanglementCounterpart, 2, 22)) == [(slot = reg[2], id = 19, tag = Tag(EntanglementCounterpart,2,22)), (slot = reg[2], id = 14, tag = Tag(EntanglementCounterpart,2,22))]
@test queryall(reg, EntanglementCounterpart, 2, 22) == queryall(reg, EntanglementCounterpart, ==(2), ==(22)) == queryall(reg, Tag(EntanglementCounterpart, 2, 22))
@test queryall(reg, Tag(EntanglementCounterpart, 2, 22); filo=false) == [(slot = reg[2], id = 14, tag = Tag(EntanglementCounterpart,2,22)), (slot = reg[2], id = 19, tag = Tag(EntanglementCounterpart,2,22))]
@test queryall(reg, EntanglementCounterpart, 2, 22; filo=false) == queryall(reg, EntanglementCounterpart, ==(2), ==(22); filo=false) == queryall(reg, Tag(EntanglementCounterpart, 2, 22); filo=false)

reg = Register(4)
tag!(reg[1], EntanglementCounterpart, 4, 9)
tag!(reg[1], EntanglementCounterpart, 5, 2)
tag!(reg[1], EntanglementCounterpart, 7, 7)
tag!(reg[1], EntanglementCounterpart, 4, 9)
tag!(reg[1], EntanglementCounterpart, 2, 3)
tag!(reg[1], EntanglementCounterpart, 4, 9)

@test reg.tags[1] == [Tag(EntanglementCounterpart, 4, 9), Tag(EntanglementCounterpart, 5, 2), Tag(EntanglementCounterpart, 7, 7), Tag(EntanglementCounterpart, 4, 9), Tag(EntanglementCounterpart, 2, 3), Tag(EntanglementCounterpart, 4, 9)]
querydelete!(reg[1], EntanglementCounterpart, 4, 9)
@test reg.tags[1] == [Tag(EntanglementCounterpart, 4, 9), Tag(EntanglementCounterpart, 5, 2), Tag(EntanglementCounterpart, 7, 7), Tag(EntanglementCounterpart, 4, 9), Tag(EntanglementCounterpart, 2, 3)]
querydelete!(reg[1], EntanglementCounterpart, 4, 9;filo=false)
@test reg.tags[1] == [Tag(EntanglementCounterpart, 5, 2), Tag(EntanglementCounterpart, 7, 7), Tag(EntanglementCounterpart, 4, 9), Tag(EntanglementCounterpart, 2, 3)]