For a new backend, the documented public integration points are the methods that
let the register API lower symbolic objects and operate on native state types.

In practice that usually means defining:

- a representation type such as `YourRepr()`;
- `newstate(::QuantumStateTrait, ::YourRepr)`;
- `default_repr(...)`;
- `nsubsystems` and `subsystemcompose` for factorized state management;
- native `apply!`, `observable`, `project_traceout!`, and `traceout!`;
- symbolic lowering through `express(..., ::YourRepr)` or `express_nolookup`;
- and, if the backend supports background evolution, `uptotime!` plus whatever
  helpers it needs such as `paulinoise`, `krausops`, or `lindbladop`.

The internal invariants called out in `.agents/registers/register-internals-and-backend-hooks.md`
are:

- `staterefs[i]` and `stateindices[i]` must agree on assignment state;
- `StateRef.registers` and `StateRef.registerindices` must keep correct
  backreferences after composition, measurement, swap, and traceout;
- operations must not move time backward;
- symbolic lowering for `apply!` and `observable` must reach concrete backend
  state methods by the time state-level dispatch happens.

Two review cautions worth keeping in mind:

- user-facing code should stay on public register operations rather than reach
  into `StateRef`;
- current docs are a bit more general than the implementation in at least one
  place: `.agents` notes that register-level `observable` currently requires the
  touched slots to already share one `StateRef`.

The source files and tests explicitly recommended for this work are:

- `src/states_registers.jl`
- `src/baseops/initialize.jl`
- `src/baseops/apply.jl`
- `src/baseops/observable.jl`
- `src/baseops/traceout.jl`
- `src/baseops/subsystemcompose.jl`
- `src/baseops/uptotime.jl`
- `test/general/register_interface_tests.jl`
- `test/general/apply_tests.jl`
- `test/general/observable_tests.jl`
- `test/general/project_traceout_tests.jl`

