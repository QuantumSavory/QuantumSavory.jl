# Message passing and queues

```@meta
DocTestSetup = quote
    using QuantumSavory
    using CairoMakie
end
```

!!! warning

    This section is rather low-level, created before a lot of user-friendly tools were added.
    The approach described here still functions well, however we now provide a more convenient interface and pre-build message passing channels.
    In particular, the tagging & querying system (based on `tag!` and `query`), the [`messagebuffer`](@ref), and the available [`channel`](@ref), [`qchannel`](@ref) and [`QuantumChannel`](@ref)
    probably cover all your needs.
    You might still be interested in reading this section in order to learn some of the low-level tooling on which the more recent developments were built.

In network simulations, a convenient synchronization primitive is the passing of messages between nodes.
The `ResumableFunctions` and `ConcurrentSim` libraries provide such primitives, convenient to use with `QuatumSavory`.

Here we run through a simple example: there are two nodes that perform certain measurements. If the measurement result is the same, then the simulation ends. If the results differ, then we reset both nodes and try again. No actual physics will be simulated here (we will just generate some random numbers).

There are a number of convenient queue structures provided by these libraries. We will focus on `Store` and `DelayChannel` both of which are FILO stacks on which you can `put` messages or `get` messages.

We use `ConcurrentSim`'s `@yield` and `@process` constructs to provide concurrency in our simulation.

First we create a `Simulation` object (to track the fictitious simulation time and currently active simulated process) and create a few FILO stacks for `put`ting and `get`ting messages.

```@example messagechannel
using QuantumSavory
using ResumableFunctions
using ConcurrentSim
using CairoMakie

sim = Simulation()
channel_1to2 = Store{Bool}(sim) # message channel from node 1 to node 2
channel_2to1 = Store{Bool}(sim) # message channel from node 2 to node 1
channel_ready = Store{Bool}(sim) # message channel for announcing system reset is done
nothing # hide
```

Now we also define a process that will be executed independently by each of the nodes: it runs a measurement, it sends the measurement result to the other node, and it waits to get a message about the other node's result.

```@example messagechannel
@resumable function do_random_measurement_transmit_receive_compare(sim, channel_out, channel_in)
    local_measurement = rand() < 0.1 # 10% chance to get `true`
    put(channel_out, local_measurement)
    other_measurement = @yield get(channel_in)
    succeeded = local_measurement == other_measurement == true
    return succeeded
end
nothing # hide
```

The system reset function is itself rather simple: just a wait followed by messaging one of the nodes that the reset has finished.

```@example messagechannel
@resumable function reset_system(sim)
    reset_duration = 1.0
    @yield timeout(sim, reset_duration)
    put(channel_ready, true)
end
nothing # hide
```

Last step of the setup is to write the event loops for each of the nodes. As a flowchart they look like the following:

```@raw html
<div class="mermaid">
graph LR
  subgraph Node 2
    direction LR
    a[Make measurement]
    b[Send measurement result]
    c[Wait to receive<br>other node's<br>measurement]
    d{Measurements<br>match}
    e[End]
    f[Wait for<br>system reset<br>confirmation]

    a --> b --> c --> d --Yes--> e
    d --No--> f --> a
  end
  subgraph Node 1
    direction LR
    A[Make measurement]
    B[Send measurement result]
    C[Wait to receive<br>other node's<br>measurement]
    D{Measurements<br>match}
    E[End]
    F[Reset system]
    G[Message<br>that system<br>is reset]

    A --> B --> C --> D --Yes--> E
    D --No--> F --> G --> A
  end</div>
```

And below we implement them in code:

```@example messagechannel
@resumable function process_node1(sim)
    while true
        succeeded = @yield @process do_random_measurement_transmit_receive_compare(sim, channel_1to2, channel_2to1)
        if succeeded
            throw(StopSimulation("Success!"))
        end
        @yield @process reset_system(sim)
    end
end

@resumable function process_node2(sim)
    while true
        succeeded = @yield @process do_random_measurement_transmit_receive_compare(sim, channel_2to1, channel_1to2)
        if succeeded
            throw(StopSimulation("Success!"))
        end
        @yield get(channel_ready) # wait in case a reset was needed
    end
end
nothing # hide
```

Finally, we schedule the two concurrent processes and run the simulation until success.

```@example messagechannel
@process process_node1(sim)
@process process_node2(sim)

ConcurrentSim.run(sim)
time_before_success = now(sim)
```

## Communication delay

Classical communication delay might be important too. There are FILO storage stacks that can simulate that, e.g. `DelayQueue(sim, delay_time)` used instead of `Storage(sim)`. Below we augment the example from above with such a delay channel and we also add some crude instrumentation and plotting.

```@example messagechannel
sim = Simulation()
communication_delay = 1.0
channel_1to2 = DelayQueue{Bool}(sim, communication_delay)
channel_2to1 = DelayQueue{Bool}(sim, communication_delay)
channel_ready = DelayQueue{Bool}(sim, communication_delay)

global_log = []

@resumable function do_random_measurement_transmit_receive_compare(sim, channel_out, channel_in)
    @yield timeout(sim, 2+rand())   # wait for the measurement to take place
    local_measurement = rand() < 0.4 # simulate a random measurement result
    put!(channel_out, local_measurement)
    other_measurement = @yield take!(channel_in)
    succeeded = local_measurement == other_measurement == true
    return succeeded
end

@resumable function reset_system(sim)
    s = now(sim)
    reset_duration = 2.0
    @yield timeout(sim, reset_duration)
    put!(channel_ready, true)
    push!(global_log, (:reset_system, s, now(sim)))
end

@resumable function process_node1(sim)
    while true
        s = now(sim)
        succeeded = @yield @process do_random_measurement_transmit_receive_compare(sim, channel_1to2, channel_2to1)
        if succeeded
            throw(StopSimulation("Success!"))
        end
        push!(global_log, (:node_1_meas_tx_rx, s, now(sim)))
        s2 = now(sim)
        @yield @process reset_system(sim)
        push!(global_log, (:node_1_wait_for_reset, s2, now(sim)))
    end
end

@resumable function process_node2(sim)
    while true
        s = now(sim)
        succeeded = @yield @process do_random_measurement_transmit_receive_compare(sim, channel_2to1, channel_1to2)
        if succeeded
            throw(StopSimulation("Success!"))
        end
        push!(global_log, (:node_2_meas_tx_rx, s, now(sim)))
        s2 = now(sim)
        @yield take!(channel_ready)
        push!(global_log, (:node_2_wait_for_reset, s2, now(sim)))
    end
end

@process process_node1(sim)
@process process_node2(sim)

ConcurrentSim.run(sim)

fig = Figure()
ax = Axis(fig[1,1],xlabel="time")
hideydecorations!(ax)

for (i, symbol) in enumerate([:node_1_meas_tx_rx,:node_2_meas_tx_rx,:reset_system,:node_1_wait_for_reset,:node_2_wait_for_reset])
    x_coords = [(x₀, x₁)
        for (s, x₀, x₁) in global_log
        if s==symbol]
    coords = [(Point(x₀,y+i/5),Point(x₁,y+i/5)) for (y,(x₀, x₁)) in enumerate(x_coords)]
    linesegments!(coords,color=Cycled(i),label=string(symbol),linewidth=10)
    flat_coords = collect(Iterators.flatten(coords))
    scatter!(flat_coords,color=Cycled(i))
end
axislegend(ax)
fig
```

The horizontal axis is simulation time. We plot the periods during which one of the following is happening:

- node 1 is performing a measurement or transmits/receives messages
- same for node 2
- the system reset is happening
- node 1 is waiting on the system reset (which happens local to it)
- node 2 is waiting to receive a message that the system reset happened.

As you can see, node 1 can start measurements before node 2 has heard that the system reset has happened, due to the communication delay.

