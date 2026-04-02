The main mental model is:

- states stay separate until physics forces them together;
- each subsystem carries its own effective simulation time; and
- background processes are declared once and applied on demand.

Factorization:

- QuantumSavory does not eagerly expand everything into one giant global state.
- If subsystems have not interacted, they can remain as separate state objects.
- When an operation couples them, the simulator composes only the joint state it
  actually needs.

That is why memory growth follows the size of entangled clusters you create,
not automatically the full product space of the whole register.

Time:

- each slot tracks local time;
- operations, observables, and synchronization points advance the touched
  subsystem to the requested time before continuing;
- untouched parts of the model do not consume work yet.

So two subsystems can sit at different effective times until an interaction
forces synchronization.

Background noise:

- you attach long-lived processes like dephasing or damping at register
  construction time;
- QuantumSavory lowers that declaration into the chosen backend when it needs to
  update the state.

That keeps protocol code focused on protocol logic instead of manually doing
“wait, evolve, apply, evolve again” bookkeeping.

If you want the precise API after the mental model, read:

- `docs/src/modeling_registers_and_time.md`
- `docs/src/backgrounds.md`
- `docs/src/register_interface.md`

