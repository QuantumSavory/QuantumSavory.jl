# Register Interface

```@meta
DocTestSetup = quote
    using QuantumSavory
end
```

A rather diverse set of simulation libraries is used under the hood. Long term the Julia Quantum Science community might be able to converge to a common interface that would slightly simplify work between the libraries, but in the interim the Julia multimethod paradigm is sufficient. Below we describe the interface that enables us to operate with many distinct underlying simulators.

## `initialize!`

Initialize the state of a register to a known state.

### `initialize!(refs::Vector{RegRef}, state; time)`

Store a `state` in the given register slots.

`refs` can also be `Tuple{Vararg{RegRef, N}}` or a single [`RegRef`](@ref).

### `initialize!(r::Vector{Register}, i::Vector{Int64}, state; time)`

`r` can also be a single [`Register`](@ref).

The `accesstimes` attributes of the slots are reset to the given `time`.

If `state<:Symbolic`, then [`consistent_representation`](@ref) is used to choose an appropriate representation based on the [`AbstractRepresentation`](@ref) properties of the register slots. Then an [`express`](@ref) call is made to transform the symbolic object into the appropriate representation.

### `initialize!(r::RegRef; time)` and `initialize!(reg::Register, i::Int64; time)`

When a `state` is not provided, a default one is calculated from `newstate`, depending on the register slot's [`QuantumStateTrait`](@ref) (e.g. qubit vs qumode) and [`AbstractRepresentation`](@ref) (e.g. ket vs tableaux).

### Interface Overview

```@raw html
<div class="mermaid">
flowchart TB
  A["<code>initialize!(refs::Vector{RegRef}, state; time)</code>"]
  B["<code>initialize!(r::Vector{Register}, i, state; time)</code>"]
  subgraph TOP [lower from registers to states]
    direction LR
  end
  D{{"<code>state<:Symbolic</code>"}}
  subgraph D1 [express state]
    direction LR
    d11["<code>consistent_representation(r,i,state)</code>"]
    d12["<code>express(state,repr)</code>"]
    d11 --> d12
  end
  D2([Store a state reference\nin the register slots])
  A --> B --> TOP --> D
  D --Yes--> D1
  D --No--> D2
  D1 --> D2
  Ap["<code>initialize!(::RegRef; time)</code>"]
  Bp["<code>initialize!(::Register, i; time)</code>"]
  Cp["<code>newstate(::QuantumStateTrait, ::AbstractRepresentation)</code>"]
  subgraph TOPp [lower from registers to states]
    direction LR
  end
  Ap --> Bp --> TOPp --> Cp ---> D2
</div>
```

## `apply!`

Apply a quantum operation to a register.

### `apply!(refs::Vector{RegRef}, operation; time)`

Applying an `operation` to the qubits referred to by the sequence of [`RegRef`](@ref)s at a specified `time`.

`refs` can also be `Tuple{Vararg{RegRef, N}}` or a single [`RegRef`](@ref).

### `apply!(regs::Vector{Register}, indices, operation; time)`

`indices` refers to the slots inside of the given `regs`.

Calls [`uptotime!`](@ref) in order to update any [`AbstractBackground`](@ref) properties.

Calls [`subsystemcompose!`](@ref) in order to make one big state. Then goes to `apply!(state, subsystem_indices, operatin; time)`.

### `apply!(state, subsystem_indices, operation; time)`

`subsystem_indices` refers to subsystems in `state`.

If `operation<:Symbolic`, then a call like `express(operation, repr)` is used to convert the symbolic `operation` into something useful for the given state type. `repr` is chosen by dispatch on `state`.

!!! warning "Limitations of symbolic-to-explicit conversion"

    Currently, the decision of how to convert a symbolic operation is based only on the `state` on which the operation would act. It can not be modified by the [`AbstractRepresentation`](@ref) properties of the `Register`s containing the state.

### Interface Overview

```@raw html
<div class="mermaid">
flowchart TB
  A["<code>apply!(refs::Vector{RegRef}, operation; time)</code>"]
  B["<code>apply!(regs::Vector{Register}, indices, operation; time)</code>"]
  subgraph TOP [lower from registers to states]
    direction LR
    B1["<code>uptotime!</code>"]
    B2["<code>subsystemcompose!</code>"]
    B1 --> B2
  end
  C["<code>apply!(state, subsystem_indices, operation; time)</code>"]
  D{{"<code>operation<:Symbolic</code>"}}
  D1["<code>express(operation, repr)</code>"]
  D2([Dispatch on state to low level implementation<br>in an independent library])
  A --> B --> TOP --> C --> D
  D --Yes--> D1
  D --No--> D2
  D1 --> D2
</div>
```

!!! warning "Limitations of symbolic-to-explicit conversion"

    The expression interface is still poorly defined, i.e. there is no interface for `repr = some_interface(state, operation)` (and as already mentioned it does not take into account the register `AbstractRepresentation` properties).

## `observable`

Measure a quantum observable.

### `observable(refs::Tuple{Vararg{RegRef, N}}, obs, something=nothing; time)`

Calculate the value of an observable on the state in the sequence of [`RegRef`](@ref)s at a specified `time`. If these registers are not instantiated, return `something`.

`refs` can also be `Tuple{Vararg{RegRef, N}}` or a single [`RegRef`](@ref).

### `observable(regs::Vector{Register}, indices, obs, something=nothing; time)`

`indices` refers to the slots inside of the given `regs`.

Calls [`uptotime!`](@ref) in order to update any [`AbstractBackground`](@ref) properties.

Calls [`subsystemcompose!`](@ref) in order to make one big state. Then goes to `observable(state, subsystem_indices, obs; time)`.

### `observable(state, subsystem_indices, obs; time)`

subsystem_indices` refers to subsystems in `state`.

If `operation<:Symbolic`, then an `express(operation, repr)` call is used to convert the symbolic `operation` into something useful for the given state type. `repr` is chosen by dispatch on `state`.

!!! warning "Limitations of symbolic-to-explicit conversion"

    Similar to the limitations faced by `apply!`

### Interface Overview

```@raw html
<div class="mermaid">
flowchart TB
  A["<code>observable(refs::Vector{RegRef}, obs, something=nothing; time)</code>"]
  B["<code>observable(regs::Vector{Register}, indices, obs, something=nothing; time)</code>"]
  subgraph TOP [lower from registers to states]
    direction LR
    B1["<code>uptotime!</code>"]
    B2["<code>subsystemcompose!</code>"]
    B1 --> B2
  end
  C["<code>observable(state, subsystem_indices, obs; time)</code>"]
  D{{"<code>obs<:Symbolic</code>"}}
  D1["<code>express(obs, repr)</code>"]
  D2([Dispatch on state to low level implementation<br>in an independent library])
  A --> B --> TOP --> C --> D
  D --Yes--> D1
  D --No--> D2
  D1 --> D2
</div>
```

## `traceout!`

TODO

## `project_traceout!`

TODO

## `uptotime!`

TODO

## `swap!`

TODO

## `overwritetime!`

TODO