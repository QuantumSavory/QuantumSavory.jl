# UUID-Based Entanglement Tracking Example

This example demonstrates the new UUID-based entanglement tracking protocol. This protocol simplifies entanglement tracking in quantum networks by assigning unique identifiers (UUIDs) to each Bell pair.

## Advantages over the History-Based Approach

The new UUID-based protocol (`EntanglementTrackerUUID`) offers several advantages over the existing history-based tracking (`EntanglementTracker`):

1. **Simpler state management**: Each pair has a single UUID that persists through swaps, rather than maintaining detailed swap history tags.

2. **Reduced message complexity**: Update messages directly identify the pair by UUID rather than requiring node/slot combinations to match history entries.

3. **Better scalability**: No accumulation of history tags, which is important for long quantum networks with many swaps.

4. **Cleaner logic**: The tracker only needs to find the slot with a given UUID and update its remote endpoint, rather than traversing history chains.

## Basic Usage

```julia
using QuantumSavory
using QuantumSavory.ProtocolZoo
using ConcurrentSim

# Create a linear network of 4 nodes
net = RegisterNet([Register(3), Register(3), Register(3), Register(3)])
sim = get_time_tracker(net)

# Create entanglers between neighboring nodes (rounds=1 means one entanglement per pair)
entangler_1_2 = EntanglerProtUUID(sim, net, 1, 2; rounds=1)
entangler_2_3 = EntanglerProtUUID(sim, net, 2, 3; rounds=1)
entangler_3_4 = EntanglerProtUUID(sim, net, 3, 4; rounds=1)

@process entangler_1_2()
@process entangler_2_3()
@process entangler_3_4()

# Run simulation to create entanglement
run(sim, 50)

# Create swappers that will perform entanglement swaps
swapper_2 = SwapperProtUUID(sim, net, 2; nodeL=<(2), nodeH=>(2), rounds=-1)
swapper_3 = SwapperProtUUID(sim, net, 3; nodeL=<(3), nodeH=>(3), rounds=-1)

# Create trackers to handle swap notifications
tracker_1 = EntanglementTrackerUUID(sim, net, 1)
tracker_2 = EntanglementTrackerUUID(sim, net, 2)
tracker_3 = EntanglementTrackerUUID(sim, net, 3)
tracker_4 = EntanglementTrackerUUID(sim, net, 4)

@process swapper_2()
@process swapper_3()
@process tracker_1()
@process tracker_2()
@process tracker_3()
@process tracker_4()

# Run the full simulation
run(sim, 1000)
```

## Comparing UUID-Based and History-Based Protocols

### UUID-Based (`EntanglerProtUUID` + `SwapperProtUUID` + `EntanglementTrackerUUID`)

**Advantages:**
- Single tag type per pair: `EntanglementUUID`
- UUID persists through swaps
- Simpler message format: `EntanglementUpdateUUID`
- No history traversal needed
- Ideal for long repeater chains

**Example tag states:**

Initial entanglement between nodes 1 and 2:
```
Node 1, slot 1: EntanglementUUID(uuid=0x1234..., remote_node=2, remote_slot=1)
Node 2, slot 1: EntanglementUUID(uuid=0x1234..., remote_node=1, remote_slot=1)
```

After swap at node 2 (connecting pairs 1-2 and 2-3):
```
Node 1, slot 1: EntanglementUUID(uuid=0x1234..., remote_node=3, remote_slot=1)
Node 3, slot 1: EntanglementUUID(uuid=0x1234..., remote_node=1, remote_slot=1)
```

### History-Based (`EntanglerProt` + `SwapperProt` + `EntanglementTracker`)

**Advantages:**
- Proven and well-tested
- Handles complex swap scenarios with detailed history

**Disadvantages:**
- Multiple tag types: `EntanglementCounterpart`, `EntanglementHistory`, `EntanglementUpdate*`, `EntanglementDelete`
- Requires traversing history chains for message forwarding
- More complex state management
- Can accumulate history tags

## Performance Considerations

The UUID-based approach is more efficient for:
- Long repeater chains (>10 nodes)
- High-frequency swaps
- Networks where tracking overhead matters

The history-based approach may be preferable when:
- Detailed debugging of swap history is needed
- Working with already-deployed systems using the history-based approach
- Specific diagnostic information from history tags is required

## Comparing with Multiple Swap Scenarios

Consider a simple swap at node 2 connecting pairs:
- Pair A: 1-2
- Pair B: 2-3

### UUID-Based Protocol:
1. Node 2 performs swap, creates swap measurement results
2. Node 2 sends `EntanglementUpdateUUID` to nodes 1 and 3
3. Nodes 1 and 3 receive updates, apply corrections, update remote endpoint
4. Done! No further message forwarding needed

### History-Based Protocol:
1. Node 2 performs swap, stores `EntanglementHistory` tags
2. Node 2 sends `EntanglementUpdate*` messages to nodes 1 and 3
3. If further swaps occurred before message delivery, nodes may need to:
   - Check `EntanglementHistory` to forward message to new location
   - Create new `EntanglementHistory` tags
   - Forward messages further through the network

## Migration Path

To migrate from `EntanglerProt` to `EntanglerProtUUID`:

**Old code:**
```julia
entangler = EntanglerProt(sim, net, 1, 2; rounds=1)
tracker = EntanglementTracker(sim, net, 1)
tracker = EntanglementTracker(sim, net, 2)
```

**New code:**
```julia
entangler = EntanglerProtUUID(sim, net, 1, 2; rounds=1)
tracker = EntanglementTrackerUUID(sim, net, 1)
tracker = EntanglementTrackerUUID(sim, net, 2)
```

The API is designed to be as similar as possible, with the main difference being
the use of UUID-based tags instead of the more complex history-based system.

## Debugging

To debug the UUID-based protocol:

```julia
using Logging

# Set logger to debug level
logger = ConsoleLogger(Logging.Debug)
global_logger(logger)

# Now run simulation - you'll see detailed debug messages about UUIDs
run(sim, time_end)
```

Debug output will show:
- UUID assignments during entanglement generation
- Swap operations and measurement results
- Message routing and tag updates
- Any warnings or errors