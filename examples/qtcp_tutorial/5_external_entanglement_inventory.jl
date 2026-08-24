# QTCP Tutorial — Script 5: External Entanglement Inventory
#
# The earlier steps let each LinkController generate a pair for each request.
# This step separates pair production from pair consumption. One persistent
# EntanglerProt fills inventory on every physical edge, and each LinkController
# claims a reciprocal pair from that inventory when QTCP requests one.

include("setup.jl")
using Random

Random.seed!(20260824)

# --- Network parameters ---
graph = grid([4, 4])
regsize = 20
T2 = 100.0
end_nodes = [1, 4, 13, 16]

# Configure every link controller to take the newest reciprocal pair tagged by
# the independently running entanglers.
sim, net = simulation_setup(
    graph,
    regsize;
    T2,
    end_nodes,
    link_controller_kwargs=(tag=EntanglementCounterpart, filo=true),
)

# Start one persistent inventory producer per physical edge.
for edge in edges(net)
    entangler = EntanglerProt(
        net,
        edge.src,
        edge.dst;
        tag=EntanglementCounterpart,
        rounds=-1,
        attempts=-1,
        success_prob=1.0,
        attempt_time=0.1,
        retry_lock_time=0.1,
        randomize=true,
        margin=18,
        hardmargin=10,
    )
    @process entangler()
end

# Let the producers establish inventory before QTCP traffic starts.
run(sim, 2.0)

function edge_has_reciprocal_inventory(net, edge)
    candidates = queryall(
        net[edge.src],
        EntanglementCounterpart,
        edge.dst,
        ❓,
        ❓;
        assigned=true,
    )
    return any(candidates) do candidate
        remote_slot = candidate.tag[3]
        pair_id = candidate.tag[4]
        1 <= remote_slot <= length(net[edge.dst]) || return false
        !isnothing(query(
            net[edge.dst][remote_slot],
            EntanglementCounterpart,
            edge.src,
            candidate.slot.idx,
            pair_id;
            assigned=true,
        ))
    end
end

inventory_ready = all(edge -> edge_has_reciprocal_inventory(net, edge), edges(net))
@assert inventory_ready "Expected reciprocal entanglement inventory on every physical edge"

# Run the same two concurrent five-pair flows as tutorial step 3.
flow1 = Flow(src=1, dst=4, npairs=5, uuid=1)
flow2 = Flow(src=13, dst=16, npairs=5, uuid=2)
put!(net[flow1.src], flow1)
put!(net[flow2.src], flow2)
run(sim, 300.0)

function count_flow_notifications!(mb, tag_type, flow)
    count = 0
    while !isnothing(querydelete!(
        mb,
        tag_type,
        flow.uuid,
        ❓,
        ❓,
        ❓,
        ❓,
        ❓,
    ))
        count += 1
    end
    return count
end

flow1_src = count_flow_notifications!(
    messagebuffer(net, flow1.src), QTCPPairBegin, flow1
)
flow1_dst = count_flow_notifications!(
    messagebuffer(net, flow1.dst), QTCPPairEnd, flow1
)
flow2_src = count_flow_notifications!(
    messagebuffer(net, flow2.src), QTCPPairBegin, flow2
)
flow2_dst = count_flow_notifications!(
    messagebuffer(net, flow2.dst), QTCPPairEnd, flow2
)

@info "External-inventory delivery counts" flow1_src flow1_dst flow2_src flow2_dst
@assert flow1_src == 5 "Expected five QTCPPairBegin notifications for flow 1"
@assert flow1_dst == 5 "Expected five QTCPPairEnd notifications for flow 1"
@assert flow2_src == 5 "Expected five QTCPPairBegin notifications for flow 2"
@assert flow2_dst == 5 "Expected five QTCPPairEnd notifications for flow 2"

@info "Both external-inventory flows delivered five Bell pairs"
