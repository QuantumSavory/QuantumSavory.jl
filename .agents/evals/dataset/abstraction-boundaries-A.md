QuantumSavory is explicitly layered.

The main levels are:

- symbolic descriptions of states, operations, observables, and some protocol
  inputs;
- numerical backends that choose how those quantum objects are represented and
  evolved;
- registers and register networks that model the hardware-facing storage and
  interaction layer; and
- a discrete-event simulator that handles classical control flow such as
  waiting, retries, messaging, and contention.

On top of that, the package also provides reusable building blocks through
`StatesZoo`, `CircuitZoo`, and `ProtocolZoo`, plus visualization tools that cut
across the whole stack.

The important boundaries are:

- the symbolic frontend describes intent, but it is not itself the simulator;
- the backend decides the concrete math and what can be simulated efficiently;
- the register layer models subsystems, time, and noise declarations;
- the event-simulation layer models protocol control, not the underlying state
  representation.

That separation is what lets you keep the same high-level model while changing
backend choice or protocol structure.

The clearest overview is in the pages "Architecture and Mental Model" and
"Why QuantumSavory Exists".

