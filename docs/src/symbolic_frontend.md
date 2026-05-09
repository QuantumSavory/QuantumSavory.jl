# [Symbolic Frontend](@id symbolic-frontend)

QuantumSavory lets you describe states, operators, observables, and many
protocol inputs symbolically before choosing a numerical backend. This is what
keeps a model stable while you change how it is simulated.

## Why This Matters

Without a symbolic frontend, changing backends usually means rewriting the same
 model in several backend-specific mathematical languages. That is slow, and it
 ties the correctness of the model to the user's familiarity with each
 representation.

QuantumSavory avoids that by letting you write the intended object first:

- a Bell pair or graph-state resource,
- a gate or observable,
- a noisy mixed state,
- or a reusable state from the StateZoo.

The backend then lowers that symbolic object to the numerical representation it
needs.

## What The Symbolic Frontend Buys You

The symbolic layer is useful for three concrete reasons:

- it removes most backend-specific syntax from day-to-day modeling,
- it lets one model run across several numerical backends, and
- it makes reusable states, circuits, and protocols easier to share because
  they can describe intent instead of one fixed numerical format.

This is why the same high-level model can often be tested with a fast
restricted backend first and then checked again with a more general backend,
without rewriting the protocol logic.

## What Still Depends On The Backend

Backend-agnostic does not mean "every symbolic object works everywhere."
Backends still differ in what they can represent efficiently, or at all.

For example:

- a stabilizer backend is a good fit for stabilizer-native symbolic objects,
- a Gaussian backend is a good fit for Gaussian continuous-variable objects,
- a general wavefunction backend accepts a wider class of objects but at higher
  cost.

The symbolic frontend therefore separates model description from backend choice,
but it does not erase the mathematical limits of a backend.

## Lowering Happens At The Boundary

The key operation is `express`, which converts a symbolic object into a
backend-specific numerical one. QuantumSavory uses that boundary repeatedly:

- when symbolic states are passed to `initialize!`,
- when symbolic operators are passed to `apply!`,
- when symbolic observables are passed to `observable`, and
- when Zoo components expose symbolic state or circuit definitions.

That is why symbolic modeling fits naturally with the register API rather than
living as a separate layer.

## Why This Improves Productivity

The productivity gain is specific: fewer model rewrites, fewer chances to make
representation-specific mistakes, and a shorter path from a hardware idea to a
working simulation. It also lowers the barrier for users who understand the
physics they want to model but do not want to become experts in every backend's
data structures.

## Where To Go Next

- Read [Choosing a Backend and Modeling Tradeoffs](@ref modeling-tradeoffs) for
  when different backends make sense.
- Read [Symbolic Expressions Reference](symbolics.md) for concrete symbolic
  objects and `express` examples.
- Read [Register Interface API](register_interface.md) for the operations that
  consume symbolic states and operators.
