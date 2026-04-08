# QTCP Tutorial README

## Tutorial Structure

The tutorial is organized as a four-step progression:

1. Start from the smallest working QTCP example
2. Add visualization to build intuition
3. Change topology and run multiple flows
4. Replace one protocol component to demonstrate modularity

The tutorial scripts live in `examples/qtcp_tutorial/`.

## Shared Setup

File:
- `examples/qtcp_tutorial/setup.jl`

What it provides:
- `simulation_setup(graph, regsize; ...)`

What it does:
- Builds the registers for each graph vertex
- Creates the `RegisterNet`
- Starts the QTCP protocol suite used by the tutorial examples:
  - `EndNodeController`
  - `NetworkNodeController`
  - `LinkController`

Why it exists:
- Keeps the tutorial scripts consistent with one another
- Avoids repeating the same setup boilerplate in every step
- Exposes the extension point needed by the custom-controller example

## Step 1: Basic Repeater Chain

File:
- `examples/qtcp_tutorial/1_chain_basic.jl`

Goal:
- Show the simplest end-to-end QTCP usage pattern.

Scenario:
- A 5-node linear chain
- One flow from node 1 to node 5
- Ten requested Bell pairs

What the script demonstrates:
- Building a graph
- Calling `simulation_setup`
- Creating a `Flow`
- Injecting the flow into the source node
- Inspecting successful delivery with `QTCPPairBegin` and `QTCPPairEnd`

Narrative role:
- This is the baseline tutorial step.
- It establishes that QTCP can be used directly at the application level with minimal code.

Expected outcome:
- Ten pairs delivered at the source
- Ten pairs delivered at the destination

## Step 2: Chain Visualization

File:
- `examples/qtcp_tutorial/2_chain_visualization.jl`

Goal:
- Keep the same basic chain as step 1, but show the runtime dynamics visually.

Scenario:
- Same 5-node chain structure
- Same one-flow application pattern
- Live visualization using `GLMakie`

What the script demonstrates:
- Attaching a Makie visualization to a QuantumSavory simulation
- Watching QDatagrams and end-to-end entanglement progression over time
- Recording the visualization to an MP4 file

Narrative role:
- Step 1 proves that the protocol works.
- Step 2 makes the dynamics understandable.

Expected outcome:
- A complete run of the chain example
- An animation file showing the evolution of the network state

Important note:
- The output path for the MP4 is configurable through `ENV["QSAVORY_QTCP_TUTORIAL_2_OUTPUT"]`
- If the variable is not set, the script defaults to `qtcp_chain.mp4`

## Step 3: Grid Topology with Multiple Flows

File:
- `examples/qtcp_tutorial/3_grid_multiflow.jl`

Goal:
- Show that the same QTCP setup works on a richer topology and with concurrent users.

Scenario:
- A 4x4 grid
- End nodes at the four corners
- Two simultaneous flows:
  - node 1 to node 16
  - node 13 to node 4
- Five requested Bell pairs per flow

What the script demonstrates:
- Moving from a chain topology to a grid topology
- Running more than one flow at a time
- Verifying successful delivery independently for both flows

Narrative role:
- This is the scalability step.
- It shows that the same user-facing pattern extends naturally to a larger network with concurrent traffic.

Expected outcome:
- Each source sees five delivered pairs
- Each destination sees five delivered pairs

## Step 4: Custom EndNodeController

File:
- `examples/qtcp_tutorial/4_custom_endnode.jl`

Goal:
- Demonstrate tutorial-level protocol customization by replacing only the end-node controller.

Scenario:
- A 5-node chain
- A side-by-side comparison between:
  - the default `EndNodeController`
  - a custom `CustomEndNodeController`

What the custom controller does:
- Starts with `initial_window = 1`
- Increases the window after every `growth_interval` successful deliveries
- Caps growth at `max_window`

What remains unchanged:
- `NetworkNodeController`
- `LinkController`
- Overall network setup pattern
- Flow injection pattern

Narrative role:
- This is the extensibility step.
- It shows how to change endpoint behavior without rewriting the rest of the protocol stack used by the tutorial.

Expected outcome:
- The default controller completes the requested flow
- The custom controller also completes the requested flow

## Recommended Reading Order

1. Read `setup.jl` once to understand the shared scaffold.
2. Run `1_chain_basic.jl` for the minimal end-to-end example.
3. Run `2_chain_visualization.jl` to build intuition for the runtime behavior.
4. Run `3_grid_multiflow.jl` to see concurrent flows on a larger topology.
5. Run `4_custom_endnode.jl` to see tutorial-level customization.

## Tutorial Tests

Each tutorial step now has a corresponding example test under `test/examples/`:

- `test/examples/qtcp_tutorial_1_tests.jl`
  - Covers `examples/qtcp_tutorial/1_chain_basic.jl`
  - Checks that the source and destination each see all 10 requested pairs

- `test/examples/qtcp_tutorial_2_tests.jl`
  - Covers `examples/qtcp_tutorial/2_chain_visualization.jl`
  - Checks that the source and destination each see all 10 requested pairs
  - Checks that the animation file is created
  - Redirects the MP4 output into a temporary directory during the test

- `test/examples/qtcp_tutorial_3_tests.jl`
  - Covers `examples/qtcp_tutorial/3_grid_multiflow.jl`
  - Checks that both flows deliver all 5 requested pairs at both endpoints

- `test/examples/qtcp_tutorial_4_tests.jl`
  - Covers `examples/qtcp_tutorial/4_custom_endnode.jl`
  - Checks that the custom controller delivers all 15 requested pairs at both endpoints
