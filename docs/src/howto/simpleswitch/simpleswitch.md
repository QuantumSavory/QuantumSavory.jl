# A Simple Entanglement Switch

This example builds around the switching protocol implemented as part of [`QuantumSavory.ProtocolZoo`](@ref "Predefined Networking Protocols"), namely [`SimpleSwitchDiscreteProt`](@ref).

An *entanglement switch* is a central node that serves many clients.
Here one switch is connected to `n` clients in a star topology.
The switch has `m` qubit slots while each client has a single qubit.
On every clock tick the switch can attempt entanglement with up to `m` of its clients and perform entanglement swaps between locally-held pairs, thereby connecting two clients to each other.
Clients continuously send the switch *requests* asking to be entangled with a particular peer, and the switch decides which requests to serve so as to keep the **backlog** of outstanding requests small.

Unlike the [color-center](@ref Cluster-State-on-Color-Centers) and [congestion-chain](@ref "A Study of Congestions over a Repeater Chain") how-tos, which hand-write their protocols to show what happens under the hood, this example is **high-level**: the switching logic, the classical bookkeeping, and the entanglement consumption are all provided as ready-made, reusable protocols from the ProtocolZoo. The example is mostly a matter of wiring them together.

Below we embed a live version of the simulation (hosted at [areweentangledyet.com/simpleswitch/](https://areweentangledyet.com/simpleswitch/)):

```@raw html
<iframe class="liveexample" src="https://areweentangledyet.com/simpleswitch/" style="height:1000px;width:1650px;"></iframe>
```

The source code is in the [`examples/simpleswitch`](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/simpleswitch) folder.
All of the base functionality lives in `setup.jl`, while the two numbered scripts run it in different circumstances:

1. **`1_interactive_visualization.jl`** — an interactive `GLMakie` dashboard with sliders for the per-pair request rates;
2. **`2_wglmakie_interactive.jl`** — the same dashboard as a `WGLMakie`/`Bonito` web app (the live demo above).

## Network Setup

The network is a [`star_graph`](https://juliagraphs.org/Graphs.jl/) with the switch at the center (index `1`) and `n` clients around it.
The switch register has `m = n-2` slots; each client register has a single qubit:

```julia
n = 5    # number of clients
m = n-2  # memory slots in the switch

graph = star_graph(n+1)                       # index 1 is the switch
switch_register  = Register(m)
client_registers = [Register(1) for _ in 1:n]
net = RegisterNet(graph, [switch_register, client_registers...])
sim = get_time_tracker(net)
```

## Client Requests

Each ordered pair of clients has a process that, at exponentially-distributed intervals, sends the switch a request to be connected to its peer.
A request is just a classical message — a `SwitchRequest` wrapped in a `Tag` and pushed onto the switch's classical `channel`:

```julia
@resumable function make_request(sim, net, client, other_client, rate_observable)
    while true
        wait_time = rand(Exponential(1/rate_observable[]))
        @yield timeout(sim, wait_time)
        put!(channel(net, client=>1), Tag(SwitchRequest(client, other_client)))
    end
end
```

The request rate of each pair is held in an `Observable` so the interactive dashboard can change it on the fly with a slider.
One `make_request` process is launched per ordered client pair:

```julia
client_pairs = [(k1,k2) for k1 in 2:n+1 for k2 in 2:n+1 if k2!=k1]
rates = [Observable(1/length(client_pairs)) for _ in client_pairs]
for ((client1, client2), rate) in zip(client_pairs, rates)
    @process make_request(sim, net, client1, client2, rate)
end
```

## The Switch Protocol

The heart of the example is a single [`SimpleSwitchDiscreteProt`](@ref) running on the switch node.
It reads the incoming `SwitchRequest`s, attempts entanglement with the relevant clients (here every link succeeds with probability `0.4` per tick), swaps the resulting local pairs to connect two clients, and prioritizes requests to keep the backlog down:

```julia
switch_protocol = SimpleSwitchDiscreteProt(net, 1, 2:n+1, fill(0.4, n))
@process switch_protocol()
```

The arguments are the network, the switch node (`1`), the client nodes (`2:n+1`), and the per-client per-tick success probabilities.
Internally the protocol maintains a `_backlog` matrix of outstanding requests per client pair, which the visualizations read directly.

## Entanglement Tracking and Consumption

Two more reusable protocols run on the client side.
An [`EntanglementTracker`](@ref) on each client keeps that client's classical metadata consistent as the switch performs swaps — without it, a client would not know which peer it ended up entangled with:

```julia
for k in 2:n+1
    @process EntanglementTracker(sim, net, k)()
end
```

An [`EntanglementConsumer`](@ref) on each unordered client pair detects when a usable end-to-end Bell pair exists between those two clients and consumes it, logging each success:

```julia
client_unordered_pairs = [(k1,k2) for k1 in 2:n+1 for k2 in 2:n+1 if k2>k1]
consumers = [EntanglementConsumer(net, k1, k2) for (k1,k2) in client_unordered_pairs]
for consumer in consumers
    @process consumer()
end
```

This is exactly the bookkeeping that the low-level examples implement by hand with `:enttrackers` arrays; here it is two lines of reusable protocol.

## Running the Simulation and Visualizations

With every process registered, the simulation is advanced with `run(sim, t)`, and the plots are refreshed on each step:

```julia
for t in range(0, 1000, step=0.1)
    run(sim, t)
    push!(backlog[], sum(switch_protocol._backlog)/(n-1)/(n-2)/2)
    for (i, consumer) in enumerate(consumers)
        consumed[][i] = length(consumer._log)
    end
    # ... notify observables driving the plots ...
end
```

The dashboard built in `1_interactive_visualization.jl` combines four views, plus a grid of sliders:

- [`registernetplot_axis`](@ref) — the switch, the clients, and their quantum states;
- **average backlog over time** — the headline measure of how well the switch keeps up with demand;
- **consumed pairs per client pair** — total successfully delivered end-to-end Bell pairs, read from each consumer's `_log`;
- **backlog per client pair** — the per-pair entries of the switch's `_backlog` matrix;
- **request-rate sliders** — one per ordered client pair (plus a global override), which write into the `rates` observables in real time so you can watch the switch react to changing demand.

## Summary of `QuantumSavory` tools employed in the simulation

We used the [`Register`](@ref) and [`RegisterNet`](@ref) data structures to hold the switch and client qubits on a star graph, and the classical `channel` of the network to carry requests.

The simulation is assembled almost entirely from high-level [`QuantumSavory.ProtocolZoo`](@ref "Predefined Networking Protocols") protocols:

- [`SimpleSwitchDiscreteProt`](@ref) for the switch's entangling/swapping/scheduling logic;
- [`EntanglementTracker`](@ref) for keeping each client's classical metadata consistent across swaps;
- [`EntanglementConsumer`](@ref) for detecting and consuming finished end-to-end pairs;
- the `SwitchRequest`/`Tag` classical-messaging layer for the client requests.

The only hand-written process is the small `make_request` helper. Everything else — the entanglement bookkeeping that the [low-level examples](@ref Cluster-State-on-Color-Centers) implement by hand — is reused from the zoo. Visualization is handled by `Makie.jl` via [`registernetplot_axis`](@ref) and standard Makie plots, and the discrete-event scheduling by `ConcurrentSim.jl`.
