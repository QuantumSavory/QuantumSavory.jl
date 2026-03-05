SUITE["tagquery"] = BenchmarkGroup(["tagquery"])
SUITE["tagquery"]["misc"] = BenchmarkGroup(["misc"])
function tagquery_interfacetest()
    r = Register(10)
    tag!(r[1], :symbol1, 2, 3)
    tag!(r[2], :symbol1, 4, 5)
    tag!(r[5], Int, 4, 5)

    @assert Tag(:symbol1, 2, 3) == Tag(:symbol1, 2, 3)
    @assert query(r, :symbol1, 4, ❓).tag == Tag(:symbol1, 4, 5)
    @assert query(r, :symbol1, 4, 5).tag == Tag(:symbol1, 4, 5)
    @assert query(r, :symbol1, ❓, ❓).tag == Tag(:symbol1, 4, 5)
    @assert query(r, :symbol2, ❓, ❓) == nothing
    @assert query(r, Int, 4, 5).tag == Tag(Int, 4, 5)
    @assert query(r, Float32, 4, 5) == nothing
    @assert query(r, Int, 4, >(5)) == nothing
    @assert query(r, Int, 4, <(6)).tag == Tag(Int, 4, 5)

    @assert [r.tag for r in queryall(r, :symbol1, ❓, ❓)] == [Tag(:symbol1, 4, 5),Tag(:symbol1, 2, 3)]
    @assert isempty(queryall(r, :symbol2, ❓, ❓))

    @assert query(r[2], Tag(:symbol1, 4, 5)).tag == Tag(:symbol1, 4, 5)
    @assert [r.tag for r in queryall(r[2], Tag(:symbol1, 4, 5))] == [Tag(:symbol1, 4, 5)]
    @assert query(r[2], :symbol1, 4, 5).tag == Tag(:symbol1, 4, 5)
    @assert [r.tag for r in queryall(r[2], :symbol1, 4, 5)] == [Tag(:symbol1, 4, 5)]

    @assert query(r[2], :symbol1, 4, ❓).tag == Tag(:symbol1, 4, 5)
    @assert [r.tag for r in queryall(r[2], :symbol1, 4, ❓)] == [Tag(:symbol1, 4, 5)]

    @assert querydelete!(r[2], :symbol1, 4, ❓).tag == Tag(:symbol1, 4, 5)
    @assert querydelete!(r[2], :symbol1, 4, ❓) === nothing
end
SUITE["tagquery"]["misc"]["from_tests"] = @benchmarkable tagquery_interfacetest()

SUITE["tagquery"]["register"] = BenchmarkGroup(["register"])
reg = Register(5)
tag!(reg[3], EntanglementCounterpart, 1, 10)
tag!(reg[3], EntanglementCounterpart, 2, 21)
tag!(reg[3], EntanglementCounterpart, 3, 30)
tag!(reg[3], EntanglementCounterpart, 2, 22)
tag!(reg[3], EntanglementCounterpart, 1, 10)
tag!(reg[3], EntanglementCounterpart, 6, 60)
tag!(reg[3], EntanglementCounterpart, 2, 23)
tag!(reg[3], EntanglementCounterpart, 1, 10)
SUITE["tagquery"]["register"]["query"] = @benchmarkable @benchmark query(reg, EntanglementCounterpart, 6, ❓; filo=true)
SUITE["tagquery"]["register"]["queryall"] = @benchmarkable @benchmark queryall(reg, EntanglementCounterpart, 6, ❓; filo=true)

SUITE["tagquery"]["messagebuffer"] = BenchmarkGroup(["messagebuffer"])
net = RegisterNet([Register(3), Register(2), Register(3)])
mb = messagebuffer(net, 2)
put!(mb, Tag(EntanglementCounterpart, 1, 10))
put!(mb, Tag(EntanglementCounterpart, 2, 21))
put!(mb, Tag(EntanglementCounterpart, 3, 30))
put!(mb, Tag(EntanglementCounterpart, 2, 22))
put!(mb, Tag(EntanglementCounterpart, 1, 10))
put!(mb, Tag(EntanglementCounterpart, 6, 60))
put!(mb, Tag(EntanglementCounterpart, 2, 23))
put!(mb, Tag(EntanglementCounterpart, 1, 10))
SUITE["tagquery"]["messagebuffer"]["query"] = @benchmarkable query(mb, EntanglementCounterpart, 6, ❓)
SUITE["tagquery"]["messagebuffer"]["querydelete"] = @benchmarkable querydelete!(_mb, EntanglementCounterpart, 6, ❓) setup=(_mb = deepcopy(mb))  evals=1

# Representative register queries used by protocols: mixed exact matches, predicate
# matches, Tag-object dispatch, and filtering by `locked`/`assigned`.
reg_mixed = Register(6)
for i in 2:5
    tag!(reg_mixed[i], EntanglementCounterpart, 1, 10 + i)
    tag!(reg_mixed[i], EntanglementCounterpart, 2, 20 + i)
    tag!(reg_mixed[i], EntanglementCounterpart, 3, 30 + i)
    tag!(reg_mixed[i], EntanglementCounterpart, 2, 120 + i)
    tag!(reg_mixed[i], EntanglementCounterpart, 1, 110 + i)
    tag!(reg_mixed[i], EntanglementCounterpart, 6, 60 + i)
    tag!(reg_mixed[i], EntanglementCounterpart, 2, 20 + i)
    tag!(reg_mixed[i], EntanglementCounterpart, 1, 310 + i)
end
initialize!(reg_mixed[2], X)
initialize!(reg_mixed[4], X)
lock(reg_mixed[5])
SUITE["tagquery"]["register"]["query_exact_filo"] = @benchmarkable query(reg_mixed, EntanglementCounterpart, 1, 12)
SUITE["tagquery"]["register"]["query_exact_fifo"] = @benchmarkable query(reg_mixed, EntanglementCounterpart, 1, 12; filo=false)
SUITE["tagquery"]["register"]["query_predicate"] = @benchmarkable query(reg_mixed, EntanglementCounterpart, ==(2), >(120))
SUITE["tagquery"]["register"]["query_tag_dispatch"] = @benchmarkable query(reg_mixed, Tag(EntanglementCounterpart, 1, 12))
SUITE["tagquery"]["register"]["query_miss"] = @benchmarkable query(reg_mixed, EntanglementCounterpart, 99, ❓)
SUITE["tagquery"]["register"]["query_assigned"] = @benchmarkable query(reg_mixed, EntanglementCounterpart, 1, ❓; assigned=true, locked=false)
SUITE["tagquery"]["register"]["query_unassigned"] = @benchmarkable query(reg_mixed, EntanglementCounterpart, 1, ❓; assigned=false, locked=false)
SUITE["tagquery"]["register"]["query_locked"] = @benchmarkable query(reg_mixed, EntanglementCounterpart, 1, ❓; locked=true)
SUITE["tagquery"]["register"]["queryall_filo"] = @benchmarkable queryall(reg_mixed, EntanglementCounterpart, 1, ❓; filo=true)
SUITE["tagquery"]["register"]["queryall_fifo"] = @benchmarkable queryall(reg_mixed, EntanglementCounterpart, 1, ❓; filo=false)
SUITE["tagquery"]["register"]["queryall_tag_dispatch"] = @benchmarkable queryall(reg_mixed, Tag(EntanglementCounterpart, 2, 22))

# Single-slot queries are common in protocol internals after a slot was selected;
# benchmark RegRef dispatch separately because it skips cross-slot checks.
reg_ref = Register(4)
tag!(reg_ref[1], EntanglementCounterpart, 4, 9)
tag!(reg_ref[1], EntanglementCounterpart, 5, 2)
tag!(reg_ref[1], EntanglementCounterpart, 7, 7)
tag!(reg_ref[1], EntanglementCounterpart, 4, 9)
tag!(reg_ref[1], EntanglementCounterpart, 2, 3)
tag!(reg_ref[1], EntanglementCounterpart, 4, 9)
SUITE["tagquery"]["register_ref"] = BenchmarkGroup(["register_ref"])
SUITE["tagquery"]["register_ref"]["query_filo"] = @benchmarkable query(reg_ref[1], EntanglementCounterpart, 4, 9)
SUITE["tagquery"]["register_ref"]["query_fifo"] = @benchmarkable query(reg_ref[1], EntanglementCounterpart, 4, 9; filo=false)
SUITE["tagquery"]["register_ref"]["queryall_filo"] = @benchmarkable queryall(reg_ref[1], EntanglementCounterpart, 4, 9)
SUITE["tagquery"]["register_ref"]["queryall_fifo"] = @benchmarkable queryall(reg_ref[1], EntanglementCounterpart, 4, 9; filo=false)
SUITE["tagquery"]["register_ref"]["query_tag_dispatch"] = @benchmarkable query(reg_ref[1], Tag(EntanglementCounterpart, 4, 9))

# Mutating tag operations are performance-critical in protocol loops.
# These benchmarks use deepcopy in setup so each evaluation runs on a fresh state.
SUITE["tagquery"]["register_mutating"] = BenchmarkGroup(["register_mutating"])
SUITE["tagquery"]["register_mutating"]["querydelete_regref_filo"] = @benchmarkable querydelete!(_slot, EntanglementCounterpart, 4, 9) setup=(_reg = deepcopy(reg_ref); _slot = _reg[1]) evals=1
SUITE["tagquery"]["register_mutating"]["querydelete_regref_fifo"] = @benchmarkable querydelete!(_slot, EntanglementCounterpart, 4, 9; filo=false) setup=(_reg = deepcopy(reg_ref); _slot = _reg[1]) evals=1
SUITE["tagquery"]["register_mutating"]["querydelete_register"] = @benchmarkable querydelete!(_reg, EntanglementCounterpart, 4, 9) setup=(_reg = deepcopy(reg_ref)) evals=1
SUITE["tagquery"]["register_mutating"]["untag_by_id"] = @benchmarkable untag!(_reg, _id) setup=(_reg = deepcopy(reg_ref); _id = query(_reg[1], EntanglementCounterpart, 4, 9).id) evals=1

# Longer tags are used by protocol-level message and control metadata.
# Benchmarking higher arity catches specialization regressions in query dispatch.
reg_long = Register(3)
tag!(reg_long[1], :longtag, 1, 2, 3, 4, 5, 6)
tag!(reg_long[2], :longtag, 1, 2, 3, 4, 5, 7)
SUITE["tagquery"]["register_high_arity"] = BenchmarkGroup(["register_high_arity"])
SUITE["tagquery"]["register_high_arity"]["query_exact"] = @benchmarkable query(reg_long, :longtag, 1, 2, 3, 4, 5, 6)
SUITE["tagquery"]["register_high_arity"]["query_predicate"] = @benchmarkable query(reg_long, :longtag, ==(1), ==(2), ==(3), ==(4), ==(5), >(5))
SUITE["tagquery"]["register_high_arity"]["queryall"] = @benchmarkable queryall(reg_long, :longtag, 1, 2, 3, 4, 5, ❓)

# MessageBuffer queries are central to protocol message handling.
# We benchmark fast-hit and deep-scan cases, plus mutating deletes.
net_front = RegisterNet([Register(3), Register(3), Register(3)])
mb_front = messagebuffer(net_front, 2)
put!(mb_front, Tag(:flow, 1, 2, 3, 4, 5, 6))
for i in 1:64
    put!(mb_front, Tag(:noise, i, i + 1, i + 2))
end

net_back = RegisterNet([Register(3), Register(3), Register(3)])
mb_back = messagebuffer(net_back, 2)
for i in 1:64
    put!(mb_back, Tag(:noise, i, i + 1, i + 2))
end
put!(mb_back, Tag(:flow, 1, 2, 3, 4, 5, 6))

SUITE["tagquery"]["messagebuffer"]["query_tag_dispatch"] = @benchmarkable query(mb_back, Tag(:flow, 1, 2, 3, 4, 5, 6))
SUITE["tagquery"]["messagebuffer"]["query_high_arity"] = @benchmarkable query(mb_back, :flow, 1, 2, 3, 4, 5, 6)
SUITE["tagquery"]["messagebuffer"]["query_high_arity_predicate"] = @benchmarkable query(mb_back, :flow, ==(1), ==(2), >(2), >(3), >(4), >(5))
SUITE["tagquery"]["messagebuffer"]["query_miss"] = @benchmarkable query(mb_back, :flow, 10, 20, 30, 40, 50, 60)
SUITE["tagquery"]["messagebuffer"]["querydelete_front"] = @benchmarkable querydelete!(_mb, :flow, 1, 2, 3, 4, 5, 6) setup=(_mb = deepcopy(mb_front)) evals=1
SUITE["tagquery"]["messagebuffer"]["querydelete_back"] = @benchmarkable querydelete!(_mb, :flow, 1, 2, 3, 4, 5, 6) setup=(_mb = deepcopy(mb_back)) evals=1
SUITE["tagquery"]["messagebuffer"]["querydelete_miss"] = @benchmarkable querydelete!(_mb, :flow, 10, 20, 30, 40, 50, 60) setup=(_mb = deepcopy(mb_back)) evals=1
