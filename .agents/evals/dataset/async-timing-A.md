Yes. That is one of the package’s main strengths.

QuantumSavory uses discrete-event simulation for protocol logic, built around:

- `@resumable` processes, which can suspend and resume; and
- `@process`, which schedules those processes on the simulation clock.

This is meant for LOCC-style workflows where events happen at different times:

- resource availability,
- classical message arrival,
- timeouts,
- or lock release.

The main wait primitives described in the docs are:

- `timeout(sim, delay)`;
- `onchange(...)`;
- `query_wait(...)`;
- `querydelete_wait!(...)`;
- and `lock(regref)`.

You can also combine waits directly:

```julia
@yield lock(q1) & lock(q2)
@yield onchange(mb) | timeout(sim, 10.0)
```

That lets you express things like:

- wait until both resources are free;
- wait for a message, but only until a deadline;
- or suspend until a specific resource or message exists.

Timing constraints also enter through network delays and background evolution:

- `classical_delay` and `quantum_delay` on a `RegisterNet`;
- explicit delay on `QuantumChannel`;
- demand-driven time advancement for subsystems with background noise.

So the short answer is yes: asynchronous protocols and finite timing are
first-class, not bolted on.

