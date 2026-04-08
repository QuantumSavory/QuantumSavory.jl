# QTCP Tutorial — Script 4: Custom EndNodeController
#
# This script demonstrates QTCP's modularity: we replace the default
# EndNodeController with a custom one that starts with a small congestion
# window (1 QDatagram in flight) and increases it over time up to a threshold.
#
# The key insight: we only modify the EndNodeController. All other protocols
# (NetworkNodeController, LinkController) remain untouched and work exactly
# as before. This is the power of QTCP's connectionless, message-based design.

include("setup.jl")

using QuantumSavory: Tag, get_time_tracker
using QuantumSavory.ProtocolZoo: AbstractProtocol,
    QDatagram, QTCPPairBegin, QTCPPairEnd,
    LinkLevelReplyAtSource, LinkLevelReplyAtHop, Flow
using QuantumSavory.ProtocolZoo.QTCP: QDatagramSuccess
import ConcurrentSim: Process
using ConcurrentSim: @yield, now, @process, timeout
using ResumableFunctions: @resumable

# --- Custom EndNodeController ---
# Differences from the default:
#   - Starts with window_size = 1 (instead of fixed 3)
#   - Increases window by 1 after every `growth_interval` delivered pairs
#   - Caps window at max_window

@kwdef struct CustomEndNodeController <: AbstractProtocol
    sim::Simulation
    net::RegisterNet
    node::Int
    # --- CUSTOMIZATION POINT 1 ---
    # The stock EndNodeController uses a fixed built-in window.
    # This custom tutorial controller starts from a smaller window and grows it.
    initial_window::Int = 1
    max_window::Int = 5
    growth_interval::Int = 2  # increase window every N delivered pairs
end

CustomEndNodeController(net::RegisterNet, node::Int; kwargs...) =
    CustomEndNodeController(;sim=get_time_tracker(net), net, node, kwargs...)

# --- CUSTOMIZATION POINT 2 ---
# This helper is not part of the stock EndNodeController.
# We add it here so self-injected QDatagrams re-enter the source node on a
# fresh scheduler event, which is important for the tutorial's window=1 start.
@resumable function inject_qdatagram_after_resubscribe(sim, net, node, qdatagram)
    @yield timeout(sim, 1e-9)
    put!(net[node], qdatagram)
end

@resumable function (prot::CustomEndNodeController)()
    (;sim, net, node, initial_window, max_window, growth_interval) = prot
    mb = messagebuffer(net, node)

    current_flows = Set{Int}()
    qdatagrams_in_flight   = Dict{Int,Int}()
    qdatagrams_sent        = Dict{Int,Int}()
    pairs_left_to_fulfill = Dict{Int,Int}()
    destination            = Dict{Int,Int}()

    # Per-flow window and delivery counter
    windows               = Dict{Int,Int}()
    delivered_since_growth = Dict{Int,Int}()

    while true
        workwasdone = true
        while workwasdone
            workwasdone = false

            # Check for new Flow
            flow = querydelete!(mb, Flow, node, ❓, ❓, ❓)
            if !isnothing(flow)
                workwasdone = true
                _, _, dst, npairs, uuid = flow.tag
                push!(current_flows, uuid)
                qdatagrams_in_flight[uuid]   = 0
                qdatagrams_sent[uuid]        = 0
                pairs_left_to_fulfill[uuid] = npairs
                destination[uuid]            = dst
                # --- CUSTOMIZATION POINT 3 ---
                # The stock EndNodeController does not track a per-flow dynamic
                # window or per-flow delivery count for growth.
                windows[uuid]                = initial_window
                delivered_since_growth[uuid] = 0
                @debug "[$(now(sim))]: CustomEndNodeController flow $(uuid) started with window=$(initial_window)"
            end

            # Check for QDatagramSuccess (ACK from destination)
            success = querydelete!(mb, QDatagramSuccess, ❓, ❓, ❓)
            if !isnothing(success)
                workwasdone = true
                _, flow_uuid, seq_num, start_time = success.tag
                start_time = start_time::Float64
                qdatagrams_in_flight[flow_uuid]   -= 1
                pairs_left_to_fulfill[flow_uuid] -= 1

                # Convert LinkLevelReplyAtSource → QTCPPairBegin
                link_reply = querydelete!(mb, LinkLevelReplyAtSource, flow_uuid, seq_num, ❓)
                @assert !isnothing(link_reply) "No LinkLevelReplyAtSource for flow $(flow_uuid), seq $(seq_num)"
                _, _, _, memory_slot = link_reply.tag
                pair_begin = QTCPPairBegin(;
                    flow_uuid,
                    flow_src=node,
                    flow_dst=success.src,
                    seq_num,
                    memory_slot,
                    start_time
                )
                put!(net[node], pair_begin)

                # --- CUSTOMIZATION POINT 4 ---
                # This window-growth policy is the main behavioral change relative
                # to the stock EndNodeController, which keeps a fixed window.
                delivered_since_growth[flow_uuid] += 1
                if delivered_since_growth[flow_uuid] >= growth_interval && windows[flow_uuid] < max_window
                    windows[flow_uuid] += 1
                    delivered_since_growth[flow_uuid] = 0
                    @debug "[$(now(sim))]: flow $(flow_uuid) window increased to $(windows[flow_uuid])"
                end

                # Clean up completed flows
                if pairs_left_to_fulfill[flow_uuid] == 0
                    delete!(current_flows, flow_uuid)
                    delete!(qdatagrams_in_flight, flow_uuid)
                    delete!(qdatagrams_sent, flow_uuid)
                    delete!(pairs_left_to_fulfill, flow_uuid)
                    delete!(destination, flow_uuid)
                    # --- CUSTOMIZATION POINT 5 ---
                    # These extra dictionaries exist only because the custom
                    # controller maintains dynamic per-flow window state.
                    delete!(windows, flow_uuid)
                    delete!(delivered_since_growth, flow_uuid)
                    @debug "[$(now(sim))]: flow $(flow_uuid) completed"
                end
            end

            # Check for incoming QDatagram (we are the destination)
            qdatagram = querydelete!(mb, QDatagram, ❓, ❓, node, ❓, ❓, ❓)
            if !isnothing(qdatagram)
                workwasdone = true
                _, flow_uuid, flow_src, flow_dst, corrections, seq_num, start_time = qdatagram.tag
                start_time = start_time::Float64
                qdatagram_success = QDatagramSuccess(flow_uuid, seq_num, start_time)
                put!(channel(net, node=>flow_src; permit_forward=true), qdatagram_success)

                link_reply = querydelete!(mb, LinkLevelReplyAtHop, flow_uuid, seq_num, ❓)
                @assert !isnothing(link_reply) "No LinkLevelReplyAtHop for flow $(flow_uuid), seq $(seq_num)"
                _, _, _, memory_slot = link_reply.tag
                pair_end = QTCPPairEnd(;
                    flow_uuid,
                    flow_src=flow_src,
                    flow_dst=node,
                    seq_num,
                    memory_slot,
                    start_time
                )
                put!(net[node], pair_end)
            end
        end

        # Send QDatagrams up to the per-flow window
        for uuid in current_flows
            # --- CUSTOMIZATION POINT 6 ---
            # The stock EndNodeController uses one fixed WINDOW constant for all
            # flows. This version reads the current per-flow window instead.
            w = windows[uuid]
            while qdatagrams_in_flight[uuid] < w && qdatagrams_in_flight[uuid] < pairs_left_to_fulfill[uuid]
                qdatagrams_in_flight[uuid] += 1
                dst        = destination[uuid]
                seq_num    = qdatagrams_sent[uuid] += 1
                start_time = now(sim)::Float64
                corrections = 0
                qdatagram = QDatagram(uuid, node, dst, corrections, seq_num, start_time)
                # --- CUSTOMIZATION POINT 7 ---
                # The stock EndNodeController does `put!(net[node], qdatagram)`
                # directly. This tutorial controller routes the reinjection
                # through the helper above so the custom window=1 behavior stays
                # scheduler-safe.
                @process inject_qdatagram_after_resubscribe(sim, net, node, qdatagram)
            end
        end

        @yield onchange(mb)
    end
end


# ====================================================================
# Run a comparison: default vs. custom controller on a 5-node chain
# ====================================================================

function count_tags(mb, tag_type)
    n = 0
    while !isnothing(querydelete!(mb, tag_type, ❓, ❓, ❓, ❓, ❓, ❓))
        n += 1
    end
    return n
end

function run_and_measure_nth_delivery(sim, net, src, dst; npairs, milestone_pair, deadline=500.0, step=0.5)
    mb_src = messagebuffer(net, src)
    mb_dst = messagebuffer(net, dst)
    delivered_src = 0
    delivered_dst = 0
    milestone_time = nothing

    for t in step:step:deadline
        run(sim, t)
        delivered_src += count_tags(mb_src, QTCPPairBegin)
        delivered_dst += count_tags(mb_dst, QTCPPairEnd)

        if isnothing(milestone_time) && delivered_src >= milestone_pair && delivered_dst >= milestone_pair
            milestone_time = now(sim)
        end

        if delivered_src >= npairs && delivered_dst >= npairs
            break
        end
    end

    return delivered_src, delivered_dst, milestone_time
end

function main()
    println("=== Default EndNodeController (fixed window = 3) ===")
    begin
        graph = grid([5]); regsize = 20
        sim, net = simulation_setup(graph, regsize; T2=100.0)
        flow = Flow(src=1, dst=5, npairs=15, uuid=1)
        put!(net[1], flow)
        n_src, n_dst, milestone_time = run_and_measure_nth_delivery(sim, net, 1, 5; npairs=flow.npairs, milestone_pair=15)
        @assert !isnothing(milestone_time) "The 15th pair was never delivered for the default controller"
        println("  Delivered: src=$n_src, dst=$n_dst / 15")
        println("  15th pair delivered at t ≈ $(round(milestone_time, digits=1))")
    end

    println("\n=== Custom EndNodeController (window 1 → 5, growth every 2 pairs) ===")
    begin
        graph = grid([5]); regsize = 20
        sim, net = simulation_setup(graph, regsize; T2=100.0, EndNodeControllerType=CustomEndNodeController)
        flow = Flow(src=1, dst=5, npairs=15, uuid=1)
        put!(net[1], flow)
        n_src, n_dst, milestone_time = run_and_measure_nth_delivery(sim, net, 1, 5; npairs=flow.npairs, milestone_pair=15)
        @assert !isnothing(milestone_time) "The 15th pair was never delivered for the custom controller"
        println("  Delivered: src=$n_src, dst=$n_dst / 15")
        println("  15th pair delivered at t ≈ $(round(milestone_time, digits=1))")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
