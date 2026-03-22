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

### The Zoos

QuantumSavory also ships reusable libraries of common states, circuits, and
protocols through the `StatesZoo`, `CircuitZoo`, and `ProtocolZoo` submodules.
These let users start from standard building blocks rather than reconstructing
everything from scratch.

## A Typical Simulation Flow

1. Construct registers and, if needed, a register network.
2. Choose subsystem properties and background processes.
3. Initialize states and apply symbolic operations.
4. Launch protocols as resumable processes in the discrete-event simulator.
5. Query observables, inspect metadata, and visualize the resulting state.

## Where To Go Next

- Read [Register Interface](@ref) for the main high-level operations.
- Read [Backend Simulators](@ref backend) for the numerical side of the model.
- Read [Discrete Event Simulator](@ref sim) for the protocol execution model.
- Read [Tagging and Querying](@ref tagging-and-querying) for protocol
  coordination.
