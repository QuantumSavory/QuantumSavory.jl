# Register Interface

```@meta
DocTestSetup = quote
    using QuantumSavory
end
```

A rather diverse set of simulation libraries is used under the hood. Long term the Julia Quantum Science community might be able to converge to a common interface that would slightly simplify work between the libraries, but in the interim the Julia multimethod paradigm is sufficient. Below we describe the interface that enables us to operate with many distinct underlying simulators.

## `initialize!`

Initialize the state of a register to a known state.

#### `initialize!(refs::Vector{RegRef}, state; time)`

Store a `state` in the given register slots.

`refs` can also be `Tuple{Vararg{RegRef, N}}` or a single [`RegRef`](@ref).

#### `initialize!(r::Vector{Register}, i::Vector{Int64}, state; time)`

`r` can also be a single [`Register`](@ref).

The `accesstimes` attributes of the slots are reset to the given `time`.

If `state<:Symbolic`, then [`consistent_representation`](@ref) is used to choose an appropriate representation based on the [`AbstractRepresentation`](@ref) properties of the register slots. Then an [`express`](@ref) call is made to transform the symbolic object into the appropriate representation.

#### `initialize!(r::RegRef; time)` and `initialize!(reg::Register, i::Int64; time)`

When a `state` is not provided, a default one is calculated from `newstate`, depending on the register slot's [`QuantumStateTrait`](@ref) (e.g. qubit vs qumode) and [`AbstractRepresentation`](@ref) (e.g. ket vs tableaux).

#### Interface Overview

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

#### `apply!(refs::Vector{RegRef}, operation; time)`

Applying an `operation` to the qubits referred to by the sequence of [`RegRef`](@ref)s at a specified `time`.

`refs` can also be `Tuple{Vararg{RegRef, N}}` or a single [`RegRef`](@ref).

#### `apply!(regs::Vector{Register}, indices, operation; time)`

`indices` refers to the slots inside of the given `regs`.

Calls [`uptotime!`](@ref) in order to update any [`AbstractBackground`](@ref) properties.

Calls [`subsystemcompose`](@ref) in order to make one big state. Then goes to `apply!(state, subsystem_indices, operatin; time)`.

#### `apply!(state, subsystem_indices, operation; time)`

`subsystem_indices` refers to subsystems in `state`.

If `operation<:Symbolic`, then `express(operation, repr, ::UseAsOperation)` is used to convert the symbolic `operation` into something workable for the given state type. `repr` is chosen by dispatch on `state`.

!!! warning "Limitations of symbolic-to-explicit conversion"

    Currently, the decision of how to convert a symbolic operation is based only on the `state` on which the operation would act. It can not be modified by the [`AbstractRepresentation`](@ref) properties of the `Register`s containing the state.

#### Interface Overview

```@raw html
<div class="mermaid">
flowchart TB
  A["<code>apply!(refs::Vector{RegRef}, operation; time)</code>"]
  B["<code>apply!(regs::Vector{Register}, indices, operation; time)</code>"]
  subgraph TOP [lower from registers to states]
    direction LR
    B1["<code>uptotime!</code>"]
    B2["<code>subsystemcompose</code>"]
    B1 --> B2
  end
  C["<code>apply!(state, subsystem_indices, operation; time)</code>"]
  D{{"<code>operation<:Symbolic</code>"}}
  D1["<code>express(operation, repr, ::UseAsOperation)</code>"]
  D2([Dispatch on state to low level implementation<br>in an independent library])
  A --> B --> TOP --> C --> D
  D --Yes--> D1
  D --No--> D2
  D1 --> D2
</div>
```

!!! warning "Limitations of symbolic-to-explicit conversion"

    As mentioned above, converting from symbolic to explicit representation for the `operation` is dependent only on the type of `state`, i.e. by the time the conversion is done, no knowledge of the register and its properties are kept (in particular its prefered representation is not considered).

!!! info "Short-circuiting the `express` dispatch"

    You can add a custom dispatch that skips the `express` functionality by defining a method `apply!(state::YourStateType, indices, operation<:Symbolic{AbstractOperator})`. This would preemt the default `apply!(state, indices, operation<:Symbolic{AbstractOperator})` containing the `express` logic. The drawback is that this would also skip the memoization employed by `express`.

## `observable`

Measure a quantum observable. The dispatch down the call three is very similar to the one for `apply!`.

#### `observable(refs::Tuple{Vararg{RegRef, N}}, obs, something=nothing; time)`

Calculate the value of an observable on the state in the sequence of [`RegRef`](@ref)s at a specified `time`. If these registers are not instantiated, return `something`.

`refs` can also be `Tuple{Vararg{RegRef, N}}` or a single [`RegRef`](@ref).

#### `observable(regs::Vector{Register}, indices, obs, something=nothing; time)`

`indices` refers to the slots inside of the given `regs`.

Calls [`uptotime!`](@ref) in order to update any [`AbstractBackground`](@ref) properties.

Calls [`subsystemcompose`](@ref) in order to make one big state. Then goes to `observable(state, subsystem_indices, obs; time)`.

#### `observable(state, subsystem_indices, obs; time)`

subsystem_indices` refers to subsystems in `state`.

If `operation<:Symbolic`, then an `express(obs, repr, ::UseAsObservable)` call is used to convert the symbolic `obs` into something workable for the given state type. `repr` is chosen by dispatch on `state`.

!!! warning "Limitations of symbolic-to-explicit conversion"

    Similar to the limitations faced by `apply!`

#### Interface Overview

```@raw html
<div class="mermaid">
flowchart TB
  A["<code>observable(refs::Vector{RegRef}, obs, something=nothing; time)</code>"]
  B["<code>observable(regs::Vector{Register}, indices, obs, something=nothing; time)</code>"]
  subgraph TOP [lower from registers to states]
    direction LR
    B1["<code>uptotime!</code>"]
    B2["<code>subsystemcompose</code>"]
    B1 --> B2
  end
  C["<code>observable(state, subsystem_indices, obs; time)</code>"]
  D{{"<code>obs<:Symbolic</code>"}}
  D1["<code>express(obs, repr, ::UseAsObservable)</code>"]
  D2([Dispatch on state to low level implementation<br>in an independent library])
  A --> B --> TOP --> C --> D
  D --Yes--> D1
  D --No--> D2
  D1 --> D2
</div>
```

!!! info "Short-circuiting the `express` dispatch"

    Similarly to the case with `apply!`, you can skips the `express` functionality by defining a method `observable(state::YourStateType, indices, obs<:Symbolic{AbstractOperator})`.

## `project_traceout!`

#### `project_traceout!(r::RegRef, basis; time)`

Project the state in `RegRef` on `basis` at a specified `time`. `basis` can be a `Vector` or `Tuple` of basis states, or it can be a `Matrix` like `Z` or `X`.

#### `project_traceout(reg::Register, i::Int, basis; time)`

Project the state in the slot in index `i` of `Register` on `basis` at a specified `time`.  `basis` can be a `Vector` or `Tuple` of basis states, or it can be a `Matrix` like `Z` or `X`.

#### `project_traceout!(f, r::RegRef, basis; time)`

Project the state in `RegRef` on `basis` at a specified `time` and apply function `f` on the projected basis state. `basis` can be a `Vector` or `Tuple` of basis states, or it can be a `Matrix` like `Z` or `X`.

#### `project_traceout!(f, reg::Register, i::Int, basis; time)`

Project the state in the slot in index `i` of `Register` on `basis` at a specified `time` and apply function `f` on the projected basis state. `basis` can be a `Vector` or `Tuple` of basis states, or it can be a `Matrix` like `Z` or `X`.
Lowers the representation from registers to states.

#### `project_traceout!(state::Union{Ket,Operator},stateindex,basis::Symbolic{AbstractOperator})`

If `basis` is an operator, call `eigvecs` to convert it into a matrix whose columns are the eigenvectors of the basis.

#### `project_traceout!(state::Union{Ket,Operator},stateindex,basis::Base.AbstractVecOrTuple{<:Symbolic{AbstractKet}})`

If `basis` is a `Vector` or `Tuple` of `Symbolic` basis states, call express to convert it to   `QuantumOpticsRepr`

#### `project_traceout!(state::Union{Ket,Operator},stateindex,psis::Base.AbstractVecOrTuple{<:Ket})`

Low level implementation to calculate the projected state of qubit at index `stateindex` in `state` out of the basis states `psis`

#### Interface Overview

```@raw html
<div class="mermaid">
flowchart TB
A["<code>project_traceout!(r::RegRef, basis; time)</code>"]
B["<code>project_traceout(reg::Register, i::Int, basis; time)</code>"]
C["<code>project_traceout!(f, r::RegRef, basis; time)</code>"]
D["<code>project_traceout!(f, reg::Register, i::Int, basis; time)</code>"]
subgraph TOP [lower from registers to states]
  direction LR
  D1["<code>reg.staterefs[i].state[]</code>"]
  D2["<code>reg.stateindices[i]</code>"]
end
E1["<code>basis::Symbolic{AbstractOperator}</code>"]
F1["<code>eigvecs(basis)</code>"]
E2["<code>basis::Base.AbstractVecOrTuple{<:Symbolic{AbstractKet}}</code>"]
F2["<code>express.(basis,(QOR,))</code>"]
G(["<code>Dispatch on state to low level implementation<br>within the library</code>"])
A --> B --> C --> D --> TOP
TOP --> E1 --> F1 --> G
TOP --> E2 --> F2 --> G
</div>
```

## `traceout!`

Perform a partial trace over a part of the system (i.e. discard a part of the system).

#### `traceout!(r::RegRef)`

Partial trace over a particular register reference.

#### `traceout!(r::Register, i::Int)`

Partial trace over slot `i` of register `r`. Calls down to the state reference stored in that particular register.

#### `traceout!(s::StateRef, i::Int)`

Partial trace over subsystem `i` of state referenced by `s`.

#### Interface Overview

```@raw html
<div class="mermaid">
flowchart TB
  A["<code>traceout!(r::RegRef)</code>"]
  B["<code>traceout!(r::Register, i::Int)</code>"]
  C["<code>traceout!(r::StateRef, i::Int)</code>"]
  D([Dispatch on state to low level implementation<br>in an independent library])
  A --> B --> C --> D
</div>
```

## `uptotime!`

TODO

## `swap!`

TODO

## `overwritetime!`

TODO