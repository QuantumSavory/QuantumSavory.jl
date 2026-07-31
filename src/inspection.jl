"""
    TagRecord

An immutable snapshot of one register tag. `slot` is the register-local slot
index and `time` is the simulator time at which the tag was attached.
"""
struct TagRecord
    id::Int128
    slot::Int
    time::Float64
    tag::Tag
end

"""
    tag_records(register::Register)
    tag_records(slot::RegRef)

Return immutable tag snapshots in insertion order, oldest first. The `RegRef`
method filters the same register-wide order to one slot.
"""
function tag_records(register::Register)
    return map(register.guids) do id
        info = register.tag_info[id]
        TagRecord(id, info.slot, info.time, info.tag)
    end
end

function tag_records(slot::RegRef)
    return [
        record for record in tag_records(slot.reg)
        if record.slot == slot.idx
    ]
end

"""
    MessageRecord

An immutable snapshot of one buffered classical message. `source` is `nothing`
for locally inserted messages and a simulator node index for network arrivals.
"""
struct MessageRecord
    id::Int128
    source::Union{Nothing,Int}
    tag::Tag
end

"""
    message_records(buffer::MessageBuffer)

Return immutable buffered-message snapshots in insertion order, oldest first.
"""
function message_records(buffer::MessageBuffer)
    return map(zip(buffer.buffer_ids, buffer.buffer)) do (id, entry)
        MessageRecord(id, entry.src, entry.tag)
    end
end

"""
    access_time(slot::RegRef)

Return the simulator-domain time through which the slot state was last
accessed or advanced.
"""
access_time(slot::RegRef)::Float64 = slot.reg.accesstimes[slot.idx]
