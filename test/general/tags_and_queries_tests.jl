using Test
using QuantumSavory
using QuantumSavory: tag_types
using QuantumSavory.ProtocolZoo: EntanglementCounterpart

@testset "Tags and Queries" begin

function strip_id(query_result)
    return (;slot=query_result.slot, tag=query_result.tag)
end

strip_id(::Nothing) = nothing

function f()

##
@test tag_types.SymbolIntInt(:symbol1, 4, 5) == Tag(:symbol1, 4, 5)

r = Register(10)
tag!(r[1], :symbol1, 2, 3)
tag!(r[2], :symbol1, 4, 5)
tag!(r[3], :symbol1, 4, 1)
tag!(r[5], Int, 4, 5)

@test Tag(:symbol1, 2, 3) == tag_types.SymbolIntInt(:symbol1, 2, 3)
@test strip_id(query(r, :symbol1, 4, ❓)) == (slot=r[3], tag=tag_types.SymbolIntInt(:symbol1, 4, 1))
@test strip_id(query(r, :symbol1, 4, 5)) == (slot=r[2], tag=tag_types.SymbolIntInt(:symbol1, 4, 5))
@test strip_id(query(r, :symbol1, ❓, ❓)) == (slot=r[3], tag=tag_types.SymbolIntInt(:symbol1, 4, 1)) #returns latest tag in filo order
@test query(r, :symbol2, ❓, ❓) == nothing
@test strip_id(query(r, Int, 4, 5)) == (slot=r[5], tag=tag_types.TypeIntInt(Int, 4, 5))
@test query(r, Float32, 4, 5) == nothing
@test query(r, Int, 4, >(5)) == nothing
@test strip_id(query(r, Int, 4, <(6))) == (slot=r[5], tag=tag_types.TypeIntInt(Int, 4, 5))

@test strip_id.(queryall(r, :symbol1, ❓, ❓)) == [(slot=r[3], tag=Tag(:symbol1, 4, 1)), (slot=r[2], tag=Tag(:symbol1, 4, 5)), (slot=r[1], tag=Tag(:symbol1, 2, 3))] # filo by default
@test isempty(queryall(r, :symbol2, ❓, ❓))

@test strip_id(query(r[2], Tag(:symbol1, 4, 5))) == (slot=r[2], tag=Tag(:symbol1, 4, 5))
@test strip_id.(queryall(r[2], Tag(:symbol1, 4, 5))) == [(slot=r[2], tag=Tag(:symbol1, 4, 5))]
@test strip_id(query(r[2], :symbol1, 4, 5)) == (slot=r[2], tag=Tag(:symbol1, 4, 5))
@test strip_id.(queryall(r[2], :symbol1, 4, 5)) == [(slot=r[2], tag=Tag(:symbol1, 4, 5))]

@test strip_id(query(r[2], :symbol1, 4, ❓)) == (slot=r[2], tag=Tag(:symbol1, 4, 5))
@test strip_id.(queryall(r[2], :symbol1, 4, ❓)) == [(slot=r[2], tag=Tag(:symbol1, 4, 5))]

@test strip_id(querydelete!(r[2], :symbol1, 4, ❓)) == (slot=r[2], tag=Tag(:symbol1, 4, 5))
@test querydelete!(r[2], :symbol1, 4, ❓) === nothing
@test strip_id(querydelete!(r[3], :symbol1, 4, ❓)) == (slot=r[3], tag=Tag(:symbol1, 4, 1))

##
# tests for fifo and filo order queries (default is filo)
# for RegRefs

reg = Register(5)
tag!(reg[3], EntanglementCounterpart, 1, 10)
tag!(reg[3], EntanglementCounterpart, 2, 21)
tag!(reg[3], EntanglementCounterpart, 3, 30)
tag!(reg[3], EntanglementCounterpart, 2, 22)
tag!(reg[3], EntanglementCounterpart, 1, 10)
tag!(reg[3], EntanglementCounterpart, 6, 60)
tag!(reg[3], EntanglementCounterpart, 2, 23)
tag!(reg[3], EntanglementCounterpart, 1, 10)

@test query(reg[3], EntanglementCounterpart, 1, 11) === nothing
@test strip_id(query(reg[3], EntanglementCounterpart, 1, 10)) == (slot = reg[3], tag = Tag(EntanglementCounterpart,1,10))
@test strip_id(query(reg[3], EntanglementCounterpart, 1, 10; filo=false)) == (slot = reg[3], tag = Tag(EntanglementCounterpart,1,10))
@test strip_id(query(reg[3], EntanglementCounterpart, 1, 10; filo=true)) == (slot = reg[3], tag = Tag(EntanglementCounterpart,1,10))
@test query(reg[3], EntanglementCounterpart, 1, 10; filo=true).id > query(reg[3], EntanglementCounterpart, 1, 10; filo=false).id
@test query(reg[3], EntanglementCounterpart, 2, ❓; filo=true).tag[3] == 23
@test query(reg[3], EntanglementCounterpart, 2, ❓; filo=false).tag[3] == 21

@test strip_id(query(reg[3], EntanglementCounterpart, 2, ❓)) == (slot = reg[3], tag = Tag(EntanglementCounterpart,2,23))
@test strip_id(query(reg[3], EntanglementCounterpart, 2, ❓; filo=false)) == (slot = reg[3], tag = Tag(EntanglementCounterpart,2,21))
@test strip_id(query(reg[3], EntanglementCounterpart, 2, ❓; filo=true)) == (slot = reg[3], tag = Tag(EntanglementCounterpart,2,23))

@test queryall(reg, EntanglementCounterpart, 1, 11) == []
default_ids = [r.id for r in queryall(reg[3], EntanglementCounterpart, 1, 10)]
@test default_ids == sort(default_ids, rev=true)
fifo_ids = [r.id for r in queryall(reg[3], EntanglementCounterpart, 1, 10; filo=false)]
@test fifo_ids == sort(fifo_ids)
filo_ids = [r.id for r in queryall(reg[3], EntanglementCounterpart, 1, 10; filo=true)]
@test filo_ids == default_ids

##
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
@test strip_id(query(reg, EntanglementCounterpart, 1, 12)) == (slot = reg[2], tag = Tag(EntanglementCounterpart,1,12))
@test query(reg, EntanglementCounterpart, 1, 12) == query(reg, EntanglementCounterpart, ==(1), ==(12))
@test query(reg, Tag(EntanglementCounterpart, 1, 10)) === nothing
@test strip_id(query(reg, Tag(EntanglementCounterpart, 1, 12))) == (slot = reg[2], tag = Tag(EntanglementCounterpart,1,12))
@test strip_id(query(reg, EntanglementCounterpart, 1, 12; filo=false)) == (slot = reg[2], tag = Tag(EntanglementCounterpart,1,12))
@test strip_id(query(reg, EntanglementCounterpart, 1, 12; filo=true)) == (slot = reg[2], tag = Tag(EntanglementCounterpart,1,12))
@test query(reg, EntanglementCounterpart, 1, 12; filo=false) == query(reg, EntanglementCounterpart, 1, ==(12); filo=false)
@test query(reg, EntanglementCounterpart, 1, 12; filo=true) == query(reg, EntanglementCounterpart, 1, ==(12); filo=true)
@test strip_id(query(reg, EntanglementCounterpart, 1, ❓; filo=false)) == (slot = reg[2], tag = Tag(EntanglementCounterpart,1,12))
@test strip_id(query(reg, EntanglementCounterpart, 1, ❓; filo=true)) == (slot = reg[4], tag = Tag(EntanglementCounterpart,1,314))

default_res = queryall(reg, EntanglementCounterpart, 1, ❓)
default_res_id = [r.id for r in default_res]
@test strip_id.(default_res) == reverse([(slot = reg[i], tag = Tag(EntanglementCounterpart, 1, j+i)) for i in 2:4 for j in (10,110,310)])
@test default_res_id == reverse(sort(default_res_id))
filo_res = queryall(reg, EntanglementCounterpart, 1, ❓; filo=true)
filo_res_id = [r.id for r in filo_res]
@test strip_id.(filo_res) == strip_id.(default_res)
@test filo_res_id == default_res_id
fifo_res = queryall(reg, EntanglementCounterpart, 1, ❓; filo=false)
fifo_res_id = [r.id for r in fifo_res]
@test strip_id.(fifo_res) == reverse(strip_id.(default_res))
@test fifo_res_id == sort(fifo_res_id)

@test strip_id.(queryall(reg, EntanglementCounterpart, 2, 22)) == [(slot = reg[2], tag = Tag(EntanglementCounterpart,2,22)), (slot = reg[2], tag = Tag(EntanglementCounterpart,2,22))]
@test strip_id.(queryall(reg, Tag(EntanglementCounterpart, 2, 22))) == [(slot = reg[2], tag = Tag(EntanglementCounterpart,2,22)), (slot = reg[2], tag = Tag(EntanglementCounterpart,2,22))]
@test queryall(reg, EntanglementCounterpart, 2, 22) == queryall(reg, EntanglementCounterpart, ==(2), ==(22)) == queryall(reg, Tag(EntanglementCounterpart, 2, 22))
@test strip_id.(queryall(reg, Tag(EntanglementCounterpart, 2, 22); filo=false)) == [(slot = reg[2], tag = Tag(EntanglementCounterpart,2,22)), (slot = reg[2], tag = Tag(EntanglementCounterpart,2,22))]
@test queryall(reg, EntanglementCounterpart, 2, 22; filo=false) == queryall(reg, EntanglementCounterpart, ==(2), ==(22); filo=false) == queryall(reg, Tag(EntanglementCounterpart, 2, 22); filo=false)

reg = Register(4)
tag!(reg[1], EntanglementCounterpart, 4, 9)
tag!(reg[1], EntanglementCounterpart, 5, 2)
tag!(reg[1], EntanglementCounterpart, 7, 7)
tag!(reg[1], EntanglementCounterpart, 4, 9)
tag!(reg[1], EntanglementCounterpart, 2, 3)
tag!(reg[1], EntanglementCounterpart, 4, 9)

@test [reg.tag_info[i].tag for i in reg.guids] == [Tag(EntanglementCounterpart, 4, 9), Tag(EntanglementCounterpart, 5, 2), Tag(EntanglementCounterpart, 7, 7), Tag(EntanglementCounterpart, 4, 9), Tag(EntanglementCounterpart, 2, 3), Tag(EntanglementCounterpart, 4, 9)]
querydelete!(reg[1], EntanglementCounterpart, 4, 9)
@test [reg.tag_info[i].tag for i in reg.guids] == [Tag(EntanglementCounterpart, 4, 9), Tag(EntanglementCounterpart, 5, 2), Tag(EntanglementCounterpart, 7, 7), Tag(EntanglementCounterpart, 4, 9), Tag(EntanglementCounterpart, 2, 3)]
querydelete!(reg[1], EntanglementCounterpart, 4, 9;filo=false)
@test [reg.tag_info[i].tag for i in reg.guids] == [Tag(EntanglementCounterpart, 5, 2), Tag(EntanglementCounterpart, 7, 7), Tag(EntanglementCounterpart, 4, 9), Tag(EntanglementCounterpart, 2, 3)]

##
# untagging tests

reg = Register(5)
id1 = tag!(reg[1], :symA, 1, 2)
id2 = tag!(reg[2], :symB, 2, 3)
id3 = tag!(reg[3], :symB, 3, 4)
id3 = tag!(reg[4], :symB, 4, 5)
@test untag!(reg[1], id1).tag == Tag(:symA, 1, 2)
@test untag!(reg, id2).tag == Tag(:symB, 2, 3)
@test_throws "Attempted to delete a nonexistent" untag!(reg, -1)

if Base.Threads.nthreads() > 1
    regs = [Register(1) for _ in 1:min(Base.Threads.nthreads(), 4)]
    Base.Threads.@threads for i in eachindex(regs)
        for _ in 1:50_000
            tag!(regs[i][1], :threaded)
        end
    end
    # Tag ids are global, even when independent registers are tagged in parallel.
    guids = vcat((reg.guids for reg in regs)...)
    @test length(guids) == length(unique(guids))
end

##
# index maintenance tests

reg = Register(4)
id1 = tag!(reg[1], :indexed, 1)
id2 = tag!(reg[2], :indexed, 2)
id3 = tag!(reg[2], :other, 3)

@test reg.tag_ids_by_slot[1] == [id1]
@test reg.tag_ids_by_slot[2] == [id2, id3]
@test reg.tag_ids_by_head[:indexed] == [id1, id2]
@test reg.tag_ids_by_head[:other] == [id3]

@test strip_id(query(reg[2], :indexed, ❓)) == (slot=reg[2], tag=Tag(:indexed, 2))
@test strip_id(query(reg, :indexed, ❓; filo=false)) == (slot=reg[1], tag=Tag(:indexed, 1))
@test strip_id(query(reg, :indexed, ❓; filo=true)) == (slot=reg[2], tag=Tag(:indexed, 2))

@test querydelete!(reg[2], :indexed, 2).id == id2
@test reg.tag_ids_by_slot[2] == [id3]
@test reg.tag_ids_by_head[:indexed] == [id1]
@test query(reg[2], :indexed, ❓) === nothing
@test strip_id(query(reg, :indexed, ❓)) == (slot=reg[1], tag=Tag(:indexed, 1))

@test untag!(reg[1], id1).tag == Tag(:indexed, 1)
@test !haskey(reg.tag_ids_by_head, :indexed)

##
# findfreeslot tests
reg = Register(5)
initialize!(reg[1], X)
lock(reg[3])

@test findfreeslot(reg).idx == 2
@test findfreeslot(reg, chooseslot=(x -> x >= 5)).idx == 5
@test findfreeslot(reg, chooseslot=1) == nothing
@test findfreeslot(reg, chooseslot=2).idx == 2
@test findfreeslot(reg, chooseslot=3) == nothing
@test findfreeslot(reg, chooseslot=3, locked=true).idx == 3

end

f()
#using BenchmarkTools
#@benchmark f()
end
