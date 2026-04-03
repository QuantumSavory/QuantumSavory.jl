The package’s main assumption is that user code should usually describe states,
operations, and observables symbolically, while the selected backend performs
the concrete numerical work.

The public register-level operations are things like:

- `initialize!`
- `apply!`
- `observable`
- `project_traceout!`
- `traceout!`

Those are the stable user-facing entry points. The exact mathematical state
update rule comes from the chosen backend after symbolic lowering.

Two important consequences follow from the docs:

1. Backend-agnostic does not mean backend-universal.
   A stabilizer backend still assumes stabilizer-friendly dynamics. A Gaussian
   backend still assumes Gaussian structure. A more general backend supports a
   wider class of operations, but at higher cost.
2. State structure is not treated as one permanently global object.
   Independent subsystems stay factorized until an interaction forces
   composition, and measurements or trace-outs reduce the state only where the
   physics requires it.

Time evolution is also part of the update rule:

- subsystems advance to the requested time when touched;
- background noise is applied lazily rather than manually woven through every
  protocol step.

So the right mental model is: the API for operations and measurement is stable,
but the actual numerical semantics depend on the representation you selected.

