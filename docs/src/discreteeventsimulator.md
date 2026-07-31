# [Discrete Event Simulator](@id sim)

```@meta
DocTestSetup = quote
    using QuantumSavory
    using ConcurrentSim
    using ResumableFunctions
end
```

Quantum network protocols are usually not "apply these gates in order and
stop." They wait for messages, reserve resources, react to timeouts, and run in
parallel with other control loops. That is why QuantumSavory uses
discrete-event simulation for protocol logic.

The two main building blocks are:

- `@resumable` from `ResumableFunctions.jl`, which defines a coroutine-like
  process that can suspend and resume;
- `@process` from `ConcurrentSim.jl`, which schedules that process on the
  simulation clock.

## Why Discrete Event Simulation Fits LOCC

LOCC protocols are driven by events:

- a Bell pair becomes available,
- a classical message arrives,
- a timeout expires,
- or a slot lock is released.

Those events may occur at different or identical simulated times, and several
protocol components may be active at once. Discrete-event execution lets each
protocol wait only on the events it cares about.

## `@resumable` Processes

A `@resumable` function can `@yield` a condition and continue only when that
condition is satisfied.

```julia
@resumable function swapper(net, node)
    mb = messagebuffer(net, node)
    msg = @yield querydelete_wait!(mb, :swap_request)

    # local quantum work happens only after the message arrives
    return msg
end
```

This style is useful because the protocol code reads in the same order as the
logical protocol: wait, receive, act.

## `@process` Starts A Running Simulation Process

Defining a resumable function is not enough. To make it participate in the
simulation, schedule it with `@process`.

```julia
sim = Simulation()
@process swapper(net, 2)
```

Once scheduled, the process runs whenever the events it is waiting on become
ready.

## Identical Timestamps Do Not Imply Order

Simulated time determines when an event becomes ready; it does not define a
relative order between otherwise independent events or processes with the same
timestamp. Any equal-time tie-breaking observed from ConcurrentSim—including
apparent insertion order—is an implementation detail and may change in a future
ConcurrentSim version.

When a protocol requires ordering, express it as a causal dependency: await the
earlier event or process, pass a message, hand off a resource, or use distinct
simulated times. Do not rely on process launch order to resolve equal timestamps.

## Reusable Protocol Processes

User-defined control flow can remain a plain `@resumable` function scheduled
with `@process`. ProtocolZoo's built-in reusable protocols additionally use
callable `AbstractProtocol` subtypes and logging-context helpers internally.
Those lifecycle and logging hooks are not a supported third-party extension
API. The custom-swapper tutorial mirrors the current internal pattern in
tutorial-local code and is maintained with the checked-in example.

## Common Wait Conditions

The most important wait sources are:

- `timeout(sim, delay)` for waiting a fixed amount of simulated time;
- `onchange(register)` or `onchange(register, Tag)` for register changes;
- `onchange(messagebuffer)` for incoming classical messages;
- `query_wait(...)` for wait-until-query-succeeds;
- `querydelete_wait!(...)` for wait-until-query-succeeds-and-consume;
- `lock(regref)` for resource acquisition.

The `query_wait` helpers are especially useful because they combine the common
"wait for change, query again, repeat" pattern into one call. `query_wait` on its own does not lock
a register or its tags -- if the protocol will consume a tag, use
`querydelete_wait!` or re-query after acquiring locks.

## Condition Combinators

Wait conditions can be combined directly.

```julia
@yield lock(q1) & lock(q2)
@yield onchange(mb) | timeout(sim, 10.0)
```

`&` means all conditions must become ready. `|` means any one of them is
enough to resume the process.

This is what makes concurrent control logic concise. A protocol can express
"wait until both resources are free" or "wait for a message, but only up to a
deadline" without manually writing an event loop.

## Locks Are Part Of Protocol Logic

Protocols often compete for the same memory slot or communication qubit.
QuantumSavory therefore treats locks as ordinary waitable conditions inside the
same event system.

That matters because concurrency control is not a separate concern in a network
simulation. It directly changes which quantum resources are available and when.

## Where The Metadata Plane Fits

Discrete-event execution and the metadata plane are designed to work together.
Protocols usually wait on metadata changes or message-buffer queries, then act
on the matching quantum resources.

That is why the protocol code can stay modular: one component publishes a fact,
another waits for it, and neither needs an explicit handle to the other's
internal state machine.

## Where To Go Next

- Read [Metadata and Protocol Composition](@ref metadata-plane) for the control
  plane built on top of these waits.
- Read [Tag and Query API](tag_query.md) for the concrete query and wait
  functions.
- Read [ProtocolZoo API](API_ProtocolZoo.md) for reusable protocols built in
  this style.
