# Background Noise Processes

Each register slot can also declare which background processes act on it. These
are long-lived physical effects such as decay, dephasing, or other noise that
is present whether or not someone is actively touching that subsystem.

```julia
reg = Register([Qubit(), Qubit()], [T2Dephasing(10.0), nothing])
```

This is a declarative noise model. You state what process is present, once, at
model construction time. You do not manually weave noise updates through every
gate, wait, and measurement in the protocol code.

## Why This Matters

Real protocol behavior often depends on waiting time. Memory lifetimes,
classical round trips, retries, and queueing delays all change the quantum
state even when no gate is being applied.

If noise were modeled by hand, every protocol would need custom bookkeeping for
"advance the state, then apply the operation, then advance it again." That is
error-prone and it makes protocol code much harder to read.

QuantumSavory keeps that bookkeeping in the framework instead.

## Time Evolution Is Demand Driven

Each subsystem carries its own local simulation time. When a protocol applies a
gate, requests an observable, or otherwise touches part of the state,
QuantumSavory advances the relevant subsystem to the requested time before
continuing.

This means:

- untouched subsystems do not consume work yet,
- protocol code stays focused on protocol logic, and
- different parts of a model can advance at different rates until an
  interaction forces synchronization.

## Backend Lowering Is Automatic

The same declared noise process may need a different mathematical treatment in
different numerical backends. One backend may use Kraus operators, another a
Lindblad generator, and another an approximation such as twirling.

QuantumSavory handles that lowering for you. You do not need to manually derive
backend-specific versions of the same physical process each time you change
representation.

## Available Background Types

Currently QuantumSavory implements:


```@example
using QuantumSavory # hide


using InteractiveUtils # hide
import PrettyTables: pretty_table # hide

function pt_to_html(args...; kwargs...) # hide
    str = pretty_table(String, args...; kwargs...) # hide
    return Base.HTML(str) # hide
end # hide
types = QuantumSavory.available_background_types() # hide
pt_to_html(types; backend = :html, show_column_labels = false) # hide
```


If you want to inspect how a declared background process is represented, use
[`paulinoise`](@ref), [`krausops`](@ref), and [`lindbladop`](@ref).

## Where To Go Next

- Read [Modeling Registers, Factorization, and Time](@ref
  modeling-registers-time) for the larger explanation of registers and
  framework-managed time.
- Read [Properties](@ref) for the subsystem side of the same model
  description.
