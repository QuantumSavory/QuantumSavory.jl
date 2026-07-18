# [Architecture and Mental Model](@id architecture)

QuantumSavory is built around a separation of concerns:

- symbolic descriptions express what state, operation, observable, or protocol
  logic you want,
- numerical backends decide how that quantum object is represented and evolved,
- registers and register networks provide the storage and interaction model, and
- a discrete-event simulator coordinates the classical control flow around the
  quantum dynamics.

This separation is what lets the same high-level model be reused across
different simulation strategies.

![QuantumSavory architecture diagram](assets/paper_figures/qsavory.png)

The diagram above summarizes the intended flow: the register interface sits at
the center, symbolic descriptions and backend simulators stay decoupled, the
`StatesZoo`, `CircuitZoo`, and `ProtocolZoo` provide reusable building blocks,
and debugging or visualization can cut across the whole stack.

## The Main Building Blocks

### Registers and Register Networks

A [`Register`](@ref) stores local quantum subsystems such as qubits or modes.
Each slot can carry its own physical properties and background processes. A
[`RegisterNet`](@ref) groups registers into a networked simulation.

### Symbolic Frontend

States, operations, and observables can be written symbolically. This lets the
user describe the intended physics first and defer the numerical representation
decision to the backend. In practice, this means the user does not need to be
an expert in the particular mathematics of each backend in order to build and
compare models.

### Numerical Backends

The symbolic frontend is not itself a simulator. QuantumSavory lowers symbolic
objects to concrete representations such as stabilizer tableaux or wavefunctions
when an operation, measurement, or time update needs them. This is valuable for
two reasons: it allows the same model to run on fast specialized simulators
when available, and it makes it possible to work with much more than ideal
qubits, including bosonic modes and other heterogeneous subsystem types.

### Discrete-Event Control

Many quantum-networking workflows are not just sequences of gates. They include
waiting, message exchange, retries, and resource contention. QuantumSavory uses
discrete-event simulation so protocols can model that control flow directly,
while the bookkeeping of simulated time remains inside the framework rather than
in ad hoc user code.

### Metadata, Tags, and Protocol Composition

Protocols do not need to be tightly hard-wired to one another. Instead, they
can coordinate through metadata attached to register slots or message buffers.
This is one of the key ideas behind protocol composability in QuantumSavory:
protocols publish and consume semantic facts about resources rather than being
glued together with bespoke classical channels and explicit handles.

### Declarative Noise and Time

Noise processes are configured as properties of the simulated hardware model,
not manually rewritten for each backend. The symbolic layer and register
interface are responsible for lowering those declarations into the chosen
representation, while time evolution is tracked by the framework as operations
and protocol events occur.

### Log Domains

QuantumSavory uses Julia's standard log-record `group` field to classify records by
subsystem. The stable groups are available as [`LOG_GROUPS`](@ref), with `backend`,
`network`, `protocol`, `simulation`, and `visualization` domains. A custom logger can
filter on these symbols in `Logging.shouldlog(logger, level, module, group, id)` before
the message and its metadata are constructed. Individual records can also carry an
`event` metadata key for a more specific machine-readable event type.

### The Zoos

QuantumSavory also ships reusable libraries of common states, circuits, and
protocols through the `StatesZoo`, `CircuitZoo`, and `ProtocolZoo` submodules.
These let users start from standard building blocks rather than reconstructing
everything from scratch.

## Structured Simulation Logging

QuantumSavory uses Julia's standard `@debug`, `@warn`, and `@error` macros for
simulation, networking, protocol, and visualization records. Routine control
flow is logged at `Debug`, recoverable anomalies at `Warn`, and invariant
violations at `Error`. Messages are short, stable descriptions such as
`"Entangled a pair"`; changing values belong in metadata instead of being
interpolated into the message.

Library records follow this schema:

- `_group` is one of `LOG_GROUPS.backend`, `LOG_GROUPS.simulation`,
  `LOG_GROUPS.protocol`, `LOG_GROUPS.network`, or
  `LOG_GROUPS.visualization`;
- `event` is a stable `Symbol`;
- simulation records include `sim_time::Float64` and
  `sim_process_id::Union{UInt,Nothing}`;
- protocol records additionally include `protocol::Symbol` and an immutable,
  ordered `nodes::Tuple{Vararg{Int}}`;
- event-specific fields use names such as `src_node`, `dst_node`,
  `remote_nodes`, `slot`, `slots`, `pair_id`, `round`, `attempts`,
  `message_type`, and `correction`.

Use [`simulation_log_context`](@ref) for a free-function process:

```julia
@debug(
    "Swapped entanglement",
    _group=LOG_GROUPS.protocol,
    event=:entanglement_swapped,
    simulation_log_context(sim)...,
    protocol=:my_swapper,
    nodes=(node,),
    slots=(slot_a, slot_b),
    remote_nodes=(alice, charlie),
)
```

Use [`QuantumSavory.ProtocolZoo.protocol_log_context`](@ref) for an
`AbstractProtocol`. It takes a node snapshot rather than retaining the protocol,
simulation, network, register, message, or query object in the log record.

```julia
@debug(
    "Entangled a pair",
    _group=LOG_GROUPS.protocol,
    event=:pair_entangled,
    protocol_log_context(prot)...,
    round=round,
    slots=(a.idx, b.idx),
    pair_id=pair_id,
    attempts=attempts,
)
```

The `_group` keyword is special to Julia's logging macros. A logger can reject
it through `Logging.shouldlog` before the message, context splat, and ordinary
metadata are constructed. `event` and the other metadata are available only
after the record has passed that early filter.

The library event vocabulary is organized by subsystem:

| Family | Events |
|---|---|
| Entangler | `free_slots_unavailable`, `pair_entangled`, `attempts_exhausted` |
| Tracker | `message_received`, `slot_lock_requested`, `slot_lock_acquired`, `message_forwarded`, `deleted_qubit_update_applied`, `message_dropped`, `stale_message_dropped`, `message_wait_started`, `message_wait_finished` |
| Consumer | `entanglement_unavailable`, `query_invalidated`, `entanglement_consumed`, `stale_pair_dropped` |
| Swapper and cutoff | `swappable_pair_unavailable`, `counterpart_tag_conflict`, `swap_update_sent`, `deletion_message_sent` |
| Switch | `memory_assignment_unavailable`, `memory_slots_assigned`, `unused_entanglement_deleted`, `client_entanglement_failed`, `clients_entangled`, `swaps_scheduled` |
| QTCP | `flow_started`, `datagram_acknowledged`, `flow_completed`, `datagram_delivered` |
| MBQC | `graph_state_established`, `measurements_completed`, `remote_message_wait_started`, `remote_message_received`, `purification_succeeded`, `corrections_started`, `corrections_completed`, `purification_failed` |
| Network | `message_forwarded`, `message_received`, `message_arrived_without_waiter` |
| Instructional protocols | Reuse the events above, plus `entanglement_swapped`, `entanglement_failed`, `sensors_entangled`, `entanglement_target_reached`, `correction_received`, `fidelity_computed`, `round_started`, `client_fused`, `round_completed`, and `flow_window_increased` |
| Visualization | `initial_state_computed` |

## A Typical Simulation Flow

1. Construct registers and, if needed, a register network.
2. Choose subsystem properties and background processes.
3. Initialize states and apply symbolic operations.
4. Launch protocols as resumable processes in the discrete-event simulator.
5. Query observables, inspect metadata, and visualize the resulting state.

## Where To Go Next

- Read [Register Interface](@ref) for the main high-level operations.
- Read [Choosing a Backend and Modeling Tradeoffs](@ref modeling-tradeoffs) for
  the numerical side of the model.
- Read [Discrete Event Simulator](@ref sim) for the protocol execution model.
- Read [Tagging and Querying](@ref tagging-and-querying) for protocol
  coordination.
