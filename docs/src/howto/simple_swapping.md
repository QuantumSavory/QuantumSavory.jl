# [Simple Entanglement Swapping on Chains and Networks](@id Simple-Entanglement-Swapping)

This how-to introduces a small protocol family centered around very local knowledge and classical messages passed between neighboring nodes:

- [`EntanglerProt`](@ref) creates nearest-neighbor entanglement.
- [`SwapperProt`](@ref) performs local swaps at repeaters.
- [`EntanglementTracker`](@ref) listens for update and delete messages and keeps the local metadata consistent enough for the rest of the stack to continue.
- [`EntanglementConsumer`](@ref) looks for end-to-end pairs and consumes them.

This is a good baseline for simple repeater-chain and small-network simulations. It is not a universal control plane, and it has known edge cases. The last section of this page shows minimal executed examples of those failure modes.

!!! note "Executed examples"
    Every code block on this page is executed as part of the documentation build. No mocking is used.

```@example simple-swapping
using QuantumSavory
using QuantumSavory.ProtocolZoo
using Random
using Logging
using Graphs
using ConcurrentSim
using ResumableFunctions

correlations(a, b) = (
    ZZ = round(real(observable((a, b), Z⊗Z)); digits = 3),
    XX = round(real(observable((a, b), X⊗X)); digits = 3),
)

history_tags(reg) = sort(
    [entry.tag for entry in queryall(reg, EntanglementHistory, ❓, ❓, ❓, ❓, ❓)];
    by = string,
)

rounded_log(rows) = [
    (
        t = round(row.t; digits = 3),
        obs1 = round(row.obs1; digits = 3),
        obs2 = round(row.obs2; digits = 3),
    )
    for row in rows
]

function captured_error_messages(f)
    io = IOBuffer()
    logger = SimpleLogger(io, Logging.Error)
    with_logger(logger) do
        f()
    end
    [
        replace(line, r"^┌ Error: " => "")
        for line in split(chomp(String(take!(io))), "\n")
        if startswith(line, "┌ Error: ")
    ]
end

function check_nodes(net, c_node, node; low = true)
    n = Int(sqrt(size(net.graph)[1]))
    c_x = c_node % n == 0 ? c_node ÷ n : (c_node ÷ n) + 1
    c_y = c_node - n * (c_x - 1)
    x = node % n == 0 ? node ÷ n : (node ÷ n) + 1
    y = node - n * (x - 1)
    low ? (c_x - x) >= 0 && (c_y - y) >= 0 : (c_x - x) <= 0 && (c_y - y) <= 0
end

function distance(n, a, b)
    x1 = a % n == 0 ? a ÷ n : (a ÷ n) + 1
    x2 = b % n == 0 ? b ÷ n : (b ÷ n) + 1
    y1 = a - n * (x1 - 1)
    y2 = b - n * (x2 - 1)
    x1 - x2 + y1 - y2
end

function choose_node(net, node, arr; low = true)
    grid_size = Int(sqrt(size(net.graph)[1]))
    low ? argmax(distance.(grid_size, node, arr)) : argmin(distance.(grid_size, node, arr))
end

nothing # hide
```

## One link: `EntanglerProt`

Start with the smallest possible case: one protocol, one edge, and no message forwarding.

```@example simple-swapping
net = RegisterNet([Register(1), Register(1)]; classical_delay = 0.1)
sim = get_time_tracker(net)

@process EntanglerProt(
    sim,
    net,
    1,
    2;
    success_prob = 1.0,
    attempt_time = 0.0,
    rounds = 1,
)()

run(sim, 0.1)

(
    left = query(net[1], EntanglementCounterpart, 2, 1).tag,
    right = query(net[2], EntanglementCounterpart, 1, 1).tag,
    observables = correlations(net[1][1], net[2][1]),
)
```

`EntanglerProt` only needs local slot availability on the two adjacent nodes. It leaves matching [`EntanglementCounterpart`](@ref) tags behind so that later protocols can discover the pair.

## Add `SwapperProt`

Now move to a three-node chain. We first create two raw Bell pairs and then let the middle node swap them.

```@example simple-swapping
net = RegisterNet([Register(1), Register(2), Register(1)]; classical_delay = 0.1)
sim = get_time_tracker(net)

@process EntanglerProt(
    sim,
    net,
    1,
    2;
    success_prob = 1.0,
    attempt_time = 0.0,
    rounds = 1,
    chooseslotB = 1,
)()

@process EntanglerProt(
    sim,
    net,
    2,
    3;
    success_prob = 1.0,
    attempt_time = 0.0,
    rounds = 1,
    chooseslotA = 2,
)()

run(sim, 0.1)

@process SwapperProt(
    sim,
    net,
    2;
    nodeL = 1,
    nodeH = 3,
    rounds = 1,
    retry_lock_time = nothing,
)()

run(sim, 0.2)

(
    node1 = query(net[1], EntanglementCounterpart, 2, 1).tag,
    repeater = history_tags(net[2]),
    node3 = query(net[3], EntanglementCounterpart, 2, 2).tag,
    end_to_end_state = correlations(net[1][1], net[3][1]),
)
```

The quantum state has already been swapped to the ends, but the classical metadata is still local: node 2 now stores [`EntanglementHistory`](@ref) records, and nodes 1 and 3 still believe they are entangled to node 2. This is why `SwapperProt` is not enough on its own.

## Add `EntanglementTracker`

`SwapperProt` emits update messages. [`EntanglementTracker`](@ref) is the protocol that consumes those messages and rewrites the local bookkeeping.

```@example simple-swapping
net = RegisterNet([Register(1), Register(2), Register(1)]; classical_delay = 0.1)
sim = get_time_tracker(net)

for node in 1:3
    @process EntanglementTracker(sim, net, node)()
end

@process EntanglerProt(
    sim,
    net,
    1,
    2;
    success_prob = 1.0,
    attempt_time = 0.0,
    rounds = 1,
    chooseslotB = 1,
)()

@process EntanglerProt(
    sim,
    net,
    2,
    3;
    success_prob = 1.0,
    attempt_time = 0.0,
    rounds = 1,
    chooseslotA = 2,
)()

@process SwapperProt(
    sim,
    net,
    2;
    nodeL = 1,
    nodeH = 3,
    rounds = 1,
    retry_lock_time = nothing,
)()

run(sim, 1.0)

(
    node1 = query(net[1], EntanglementCounterpart, 3, 1).tag,
    repeater = history_tags(net[2]),
    node3 = query(net[3], EntanglementCounterpart, 1, 1).tag,
    end_to_end_state = correlations(net[1][1], net[3][1]),
)
```

This is the basic coordination pattern of the protocol family:

1. local protocols act on local qubits,
2. they emit classical updates,
3. trackers reconcile those updates with local metadata,
4. downstream protocols discover the new state by querying tags.

## Add `EntanglementConsumer`

The consumer is another coordinator. It does not create or reroute entanglement. It waits for end-to-end [`EntanglementCounterpart`](@ref) tags, checks the corresponding pair, records the result, and traces the pair out.

```@example simple-swapping
net = RegisterNet([Register(4), Register(8), Register(4)]; classical_delay = 0.1)
sim = get_time_tracker(net)

for node in 1:3
    @process EntanglementTracker(sim, net, node)()
end

@process EntanglerProt(
    sim,
    net,
    1,
    2;
    success_prob = 1.0,
    attempt_time = 0.0,
    rounds = 4,
    retry_lock_time = nothing,
)()

@process EntanglerProt(
    sim,
    net,
    2,
    3;
    success_prob = 1.0,
    attempt_time = 0.0,
    rounds = 4,
    retry_lock_time = nothing,
)()

@process SwapperProt(
    sim,
    net,
    2;
    nodeL = 1,
    nodeH = 3,
    rounds = 4,
    retry_lock_time = nothing,
)()

consumer = EntanglementConsumer(sim, net, 1, 3; period = nothing)
@process consumer()

run(sim, 1.0)

rounded_log(consumer._log)
```

In larger simulations this is the place where an application, benchmark, or higher-level network service would observe the final pair.

## The Same Pattern On A Tiny Network

The same four coordinators can be used on a network instead of a chain. The only extra ingredient is a local policy for `SwapperProt`: each repeater needs a predicate for what counts as a "low" candidate, what counts as a "high" candidate, and how to choose one from each side.

The predicates below are the small-grid version of the ones used in [Entanglement Generation On A Repeater Grid](@ref Entanglement-Generation-On-A-Repeater-Grid).

```@example simple-swapping
graph = grid([2, 2])
net = RegisterNet(graph, [Register(4) for _ in 1:4]; classical_delay = 1e-9)
sim = get_time_tracker(net)

for (; src, dst) in edges(net)
    @process EntanglerProt(
        sim,
        net,
        src,
        dst;
        success_prob = 1.0,
        attempt_time = 0.0,
        rounds = 1,
    )()
end

for node in 2:3
    l(x) = check_nodes(net, node, x)
    h(x) = check_nodes(net, node, x; low = false)
    cL(arr) = choose_node(net, node, arr)
    cH(arr) = choose_node(net, node, arr; low = false)
    @process SwapperProt(
        sim,
        net,
        node;
        nodeL = l,
        nodeH = h,
        chooseL = cL,
        chooseH = cH,
        rounds = 1,
        retry_lock_time = nothing,
    )()
end

for node in vertices(net)
    @process EntanglementTracker(sim, net, node)()
end

run(sim, 1.0)

end_to_end = sort(
    queryall(net[1], EntanglementCounterpart, 4, ❓);
    by = entry -> entry.tag[3],
)

(
    tags = [entry.tag for entry in end_to_end],
    observables = [correlations(entry.slot, net[4][entry.tag[3]]) for entry in end_to_end],
)
```

The network is still controlled locally:

- entanglers know only their edge,
- swappers know only their node and their local low/high policy,
- trackers know only their local tags plus the messages they receive,
- consumers know only the two end nodes they care about.

## Issues And Workarounds

!!! warning "This protocol family has known edge cases"
    The bookkeeping is intentionally local and lightweight. Under enough contention, delayed update/delete messages can refer to slots that have already been reused or reinterpreted. These cases now produce error logs instead of aborting the simulation, but the underlying protocol limitation is still present.

The following two examples are minimal executed versions of that behavior, inspired by [issue #303](https://github.com/QuantumSavory/QuantumSavory.jl/issues/303).

### Stale Tracker Updates

```@example simple-swapping
function tracker_edge_case_messages()
    captured_error_messages() do
        Random.seed!(1)
        graph = grid([4])
        noisemodel = Depolarization(1e6)
        registers = vcat([Register(20)], [Register(4, noisemodel) for _ in 1:2], [Register(20)])
        net = RegisterNet(graph, registers; classical_delay = 20.0 / 2e8 * 1e6)
        sim = get_time_tracker(net)

        for node in 1:4
            @process EntanglementTracker(sim, net, node)()
        end
        for node in 2:3
            @process SwapperProt(sim, net, node; nodeL = <(node), nodeH = >(node), retry_lock_time = nothing)()
        end
        for node in 1:3
            @process EntanglerProt(
                sim,
                net,
                node,
                node + 1;
                rate = 10.0,
                rounds = -1,
                margin = 1,
                retry_lock_time = nothing,
            )()
        end

        run(sim, 10)
    end
end

tracker_edge_case_messages()[1]
```

This is the current "keep running" behavior: the tracker detects that the forwarded update no longer matches the local bookkeeping and drops the message.

### Stale Consumer Pairs

```@example simple-swapping
function consumer_edge_case_messages()
    captured_error_messages() do
        Random.seed!(1)
        graph = grid([4])
        noisemodel = Depolarization(1e6)
        registers = vcat([Register(20)], [Register(4, noisemodel) for _ in 1:2], [Register(20)])
        net = RegisterNet(graph, registers; classical_delay = 20.0 / 2e8 * 1e6)
        sim = get_time_tracker(net)

        for node in 1:4
            @process EntanglementTracker(sim, net, node)()
        end
        for node in 2:3
            @process SwapperProt(sim, net, node; nodeL = <(node), nodeH = >(node), retry_lock_time = nothing)()
        end
        for node in 1:3
            @process EntanglerProt(
                sim,
                net,
                node,
                node + 1;
                rate = 10.0,
                rounds = -1,
                margin = 1,
                retry_lock_time = nothing,
            )()
        end

        @process EntanglementConsumer(sim, net, 1, 4; period = nothing)()
        run(sim, 10)
    end
end

filter(contains("EntanglementConsumer"), consumer_edge_case_messages())[1]
```

Here the consumer found two end-node slots with matching classical tags, but the actual quantum state behind those slots was no longer a clean two-qubit pair. The consumer drops that pair instead of calling `real(::Nothing)` and aborting the simulation.

### Practical Workarounds

These are mitigations, not fixes:

- Keep examples and tests on the happy path with a small positive `classical_delay` such as `1e-9` instead of a same-timestamp zero-delay channel.
- Reduce slot-reuse pressure by using larger registers and by leaving slack with `margin` / `hardmargin` on [`EntanglerProt`](@ref).
- When qubit age matters, combine the `agelimit` option on [`SwapperProt`](@ref) with [`CutoffProt`](@ref), as in the repeater-grid examples, so that obviously stale pairs are not selected for swaps.
- Treat the emitted error logs as evidence that this baseline coordinator set has reached one of its unsupported races. If your application needs unambiguous matching under heavy contention, this local-message design is too weak on its own.

For larger end-to-end examples built on the same coordinator family, see [1st-gen Repeater - simpler implementation](firstgenrepeater_v2/firstgenrepeater_v2.md) and [Entanglement Generation On A Repeater Grid](@ref Entanglement-Generation-On-A-Repeater-Grid).
