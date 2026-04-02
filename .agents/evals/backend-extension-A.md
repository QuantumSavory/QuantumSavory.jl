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

The key internal invariants are:

- `staterefs[i]` and `stateindices[i]` must agree on assignment state;
- `StateRef.registers` and `StateRef.registerindices` must keep correct
  backreferences after composition, measurement, swap, and traceout;
- operations must not move time backward;
- symbolic lowering for `apply!` and `observable` must reach concrete backend
  state methods by the time state-level dispatch happens.

Two review cautions worth keeping in mind:

- user-facing code should stay on public register operations rather than reach
  into `StateRef`;
- be careful not to overstate behavior in user-facing docs: one current caveat
  is that register-level `observable` expects the touched slots to already
  share one state object.

In practice, review the existing register operations, factorization logic, time
evolution paths, and the current validation coverage around register interface,
`apply!`, `observable`, and `project_traceout!`.
