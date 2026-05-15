"""
$TYPEDEF

Request for [`SuperdenseCodingProt`](@ref) to send two classical bits from `src`
to `dst` by consuming one shared Bell pair and one direct quantum-channel use.

$TYPEDFIELDS

The request is expected in `messagebuffer(net, src)` and is serialized as
`Tag(SuperdenseMessage, src, dst, bit1, bit2, uuid)`.
"""
struct SuperdenseMessage
    "the node sending the encoded qubit"
    src::Int
    "the node decoding the message"
    dst::Int
    "the two classical bits to transmit"
    bits::NTuple{2,Int}
    "application-level identifier for matching deliveries"
    uuid::Int

    function SuperdenseMessage(src::Int, dst::Int, bits::NTuple{2,Int}, uuid::Int)
        _check_superdense_bits(bits)
        new(src, dst, bits, uuid)
    end
end

SuperdenseMessage(src::Int, dst::Int, bit1::Int, bit2::Int, uuid::Int) =
    SuperdenseMessage(src, dst, (bit1, bit2), uuid)
SuperdenseMessage(; src::Int, dst::Int, bits::NTuple{2,Int}, uuid::Int) =
    SuperdenseMessage(src, dst, bits, uuid)

Base.show(io::IO, tag::SuperdenseMessage) =
    print(io, "SuperdenseMessage `$(tag.uuid)` | $(tag.src) -> $(tag.dst) | bits $(tag.bits)")
Tag(tag::SuperdenseMessage) = Tag(SuperdenseMessage, tag.src, tag.dst, tag.bits[1], tag.bits[2], tag.uuid)

"""
$TYPEDEF

Delivery emitted by [`SuperdenseCodingProt`](@ref) after Bob decodes a
superdense-coding request.

$TYPEDFIELDS

The delivery is placed in `messagebuffer(net, dst)` and is serialized as
`Tag(SuperdenseDelivery, src, dst, bit1, bit2, uuid, finish_time)`.
"""
struct SuperdenseDelivery
    "the node that sent the encoded qubit"
    src::Int
    "the node that decoded the message"
    dst::Int
    "the decoded two-bit payload"
    bits::NTuple{2,Int}
    "application-level identifier copied from the request"
    uuid::Int
    "simulation time at which decoding finished"
    finish_time::Float64

    function SuperdenseDelivery(src::Int, dst::Int, bits::NTuple{2,Int}, uuid::Int, finish_time::Float64)
        _check_superdense_bits(bits)
        new(src, dst, bits, uuid, finish_time)
    end
end

SuperdenseDelivery(src::Int, dst::Int, bit1::Int, bit2::Int, uuid::Int, finish_time::Float64) =
    SuperdenseDelivery(src, dst, (bit1, bit2), uuid, finish_time)
SuperdenseDelivery(; src::Int, dst::Int, bits::NTuple{2,Int}, uuid::Int, finish_time::Float64) =
    SuperdenseDelivery(src, dst, bits, uuid, finish_time)

Base.show(io::IO, tag::SuperdenseDelivery) =
    print(io, "SuperdenseDelivery `$(tag.uuid)` | $(tag.src) -> $(tag.dst) | bits $(tag.bits) at $(tag.finish_time)")
Tag(tag::SuperdenseDelivery) =
    Tag(SuperdenseDelivery, tag.src, tag.dst, tag.bits[1], tag.bits[2], tag.uuid, tag.finish_time)

function _check_superdense_bits(bits::NTuple{2,Int})
    all(bit -> bit == 0 || bit == 1, bits) ||
        throw(ArgumentError("Superdense coding payload bits must be 0 or 1."))
    return bits
end

_is_superdense_bit(bit::Int) = bit == 0 || bit == 1
_is_superdense_bit(_) = false
_is_superdense_uuid(uuid::Int) = true
_is_superdense_uuid(_) = false

const SuperdenseLogEntry = @NamedTuple{
    start_time::Float64,
    finish_time::Float64,
    uuid::Int,
    bits::NTuple{2,Int},
    send_slot::Int,
    entangled_slot::Int,
    receive_slot::Int,
}

"""
$TYPEDEF

Protocol primitive for entanglement-assisted superdense coding between two
directly connected nodes.

`SuperdenseCodingProt` listens for [`SuperdenseMessage`](@ref) requests in the
source node's message buffer. For each request, it consumes one reciprocal
[`EntanglementCounterpart`](@ref) pair between `nodeA` and `nodeB`, encodes the
two requested bits on Alice's half with [`SDEncode`](@ref), sends that qubit over
`qchannel(net, nodeA => nodeB)`, decodes with [`SDDecode`](@ref), and emits a
[`SuperdenseDelivery`](@ref) in Bob's message buffer. Quantum-channel transfers
started by this protocol are serialized through a resource stored in the
network's directed-edge metadata.

The protocol requires a direct quantum channel between `nodeA` and `nodeB`, and
the tagged entangled resource is expected to be in the Bell-pair convention used
by [`SDEncode`](@ref) and [`SDDecode`](@ref). Bob also needs one additional
free receive slot; his tagged Bell-pair half remains in place for decoding.

$TYPEDFIELDS
"""
@kwdef struct SuperdenseCodingProt <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex index of the sender node"""
    nodeA::Int
    """the vertex index of the receiver node"""
    nodeB::Int
    """time period between resource retries (`nothing` for waiting on message/tag events)"""
    period::Union{Float64,Nothing} = 0.1
    """time between entanglement-resource retries when `period === nothing`; unlocks are not tag events"""
    resource_retry_time::Float64 = 0.1
    """time between receive-slot retries when `period === nothing`; slot availability is not a tag event"""
    receive_slot_retry_time::Float64 = 0.1
    """tag type used to identify shared entanglement; defaults to `EntanglementCounterpart`"""
    tag::Any = EntanglementCounterpart
    """function `Int->Bool` or an integer slot number for Bob's receive slot"""
    chooseslotB::Union{Int,Function} = alwaystrue
    """whether Bob's receive slot should be selected randomly from eligible slots"""
    randomize::Bool = false
    """delivery log for debugging and performance analysis"""
    _log::Vector{SuperdenseLogEntry} = SuperdenseLogEntry[]
end

function SuperdenseCodingProt(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...)
    return SuperdenseCodingProt(; sim, net, nodeA, nodeB, kwargs...)
end

function SuperdenseCodingProt(net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...)
    return SuperdenseCodingProt(get_time_tracker(net), net, nodeA, nodeB; kwargs...)
end

function _wait_for_superdense_message(prot::SuperdenseCodingProt, mb)
    if isnothing(prot.period)
        return onchange(mb)
    else
        return onchange(mb) | timeout(prot.sim, prot.period::Float64)
    end
end

function _wait_for_superdense_resources(prot::SuperdenseCodingProt, regA::Register, regB::Register)
    if isnothing(prot.period)
        return onchange(regA, Tag) | onchange(regB, Tag) | timeout(prot.sim, prot.resource_retry_time)
    else
        return onchange(regA, Tag) | onchange(regB, Tag) | timeout(prot.sim, prot.period::Float64)
    end
end

function _wait_for_superdense_receive_slot(prot::SuperdenseCodingProt, regB::Register)
    if isnothing(prot.period)
        return timeout(prot.sim, prot.receive_slot_retry_time)
    else
        return onchange(regB, Tag) | timeout(prot.sim, prot.period::Float64)
    end
end

function _superdense_qchannel_resource(prot::SuperdenseCodingProt)
    metadata = get!(prot.net.directed_edge_metadata, prot.nodeA => prot.nodeB) do
        Dict{Symbol,Any}()
    end
    return get!(metadata, :qchannel_resource) do
        Resource(prot.sim, 1)
    end::Resource
end

function _superdense_qchannel(prot::SuperdenseCodingProt)
    edge = prot.nodeA => prot.nodeB
    haskey(prot.net.qchannels, edge) ||
        throw(ArgumentError("SuperdenseCodingProt requires a direct quantum channel from node $(prot.nodeA) to node $(prot.nodeB)."))
    return qchannel(prot.net, edge)
end

function _query_superdense_pair(prot::SuperdenseCodingProt, regA::Register, regB::Register)
    for queryA in queryall(regA, prot.tag, prot.nodeB, ❓; locked=false, assigned=true)
        remote_slot = queryA.tag[3]
        remote_slot isa Int || continue
        remote_slot in eachindex(regB.staterefs) || continue
        queryB = query(regB[remote_slot], prot.tag, prot.nodeA, queryA.slot.idx; locked=false, assigned=true)
        isnothing(queryB) || return queryA, queryB
    end
    return nothing
end

@resumable function (prot::SuperdenseCodingProt)()
    regA = prot.net[prot.nodeA]
    regB = prot.net[prot.nodeB]
    mbA = messagebuffer(prot.net, prot.nodeA)
    qc = _superdense_qchannel(prot)
    qchannel_resource = _superdense_qchannel_resource(prot)

    while true
        msg = query(
            mbA,
            SuperdenseMessage,
            prot.nodeA,
            prot.nodeB,
            _is_superdense_bit,
            _is_superdense_bit,
            _is_superdense_uuid,
        )
        if isnothing(msg)
            @yield _wait_for_superdense_message(prot, mbA)
            continue
        end
        _, _, _, bit1, bit2, uuid = msg.tag
        bits = (bit1::Int, bit2::Int)
        uuid = uuid::Int

        pair = _query_superdense_pair(prot, regA, regB)
        if isnothing(pair)
            @yield _wait_for_superdense_resources(prot, regA, regB)
            continue
        end
        queryA, queryB = pair

        receive_slot = findfreeslot(regB; chooseslot=prot.chooseslotB, randomize=prot.randomize)
        if isnothing(receive_slot)
            @yield _wait_for_superdense_receive_slot(prot, regB)
            continue
        end

        send_slot = queryA.slot
        entangled_slot = queryB.slot
        receive_slot = receive_slot::RegRef
        @yield lock(send_slot) & lock(entangled_slot) & lock(receive_slot) & lock(qchannel_resource)

        queryA = query(send_slot, prot.tag, prot.nodeB, entangled_slot.idx; locked=true, assigned=true)
        queryB = query(entangled_slot, prot.tag, prot.nodeA, send_slot.idx; locked=true, assigned=true)
        if isnothing(queryA) || isnothing(queryB) || isassigned(receive_slot)
            unlock(send_slot)
            unlock(entangled_slot)
            unlock(receive_slot)
            unlock(qchannel_resource)
            continue
        end

        msg = querydelete!(mbA, SuperdenseMessage, prot.nodeA, prot.nodeB, bit1, bit2, uuid)
        if isnothing(msg)
            unlock(send_slot)
            unlock(entangled_slot)
            unlock(receive_slot)
            unlock(qchannel_resource)
            continue
        end

        start_time = now(prot.sim)::Float64
        uptotime!((send_slot, entangled_slot), start_time)
        untag!(send_slot, queryA.id)
        untag!(entangled_slot, queryB.id)

        SDEncode()(send_slot, bits)
        put!(qc, send_slot)
        @yield take!(qc, receive_slot)
        decoded_bits = SDDecode()(receive_slot, entangled_slot)
        finish_time = now(prot.sim)::Float64

        put!(regB, SuperdenseDelivery(prot.nodeA, prot.nodeB, decoded_bits, uuid, finish_time))
        push!(
            prot._log,
            (;
                start_time,
                finish_time,
                uuid,
                bits=decoded_bits,
                send_slot=send_slot.idx,
                entangled_slot=entangled_slot.idx,
                receive_slot=receive_slot.idx,
            ),
        )

        unlock(send_slot)
        unlock(entangled_slot)
        unlock(receive_slot)
        unlock(qchannel_resource)
    end
end
