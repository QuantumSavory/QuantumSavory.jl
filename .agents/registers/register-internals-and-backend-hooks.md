# Register Internals, Time Semantics, and Backend Hooks

Open this file when:

- changing register internals or backend lowering;
- reviewing `initialize!`, `apply!`, `observable`, `traceout!`, `project_traceout!`, or `uptotime!`;
- adding a new backend representation or state type;
- debugging factorization, backreferences, or time-order bugs.

Do not use this file for simple user guidance.
Use `.agents/registers/register-interface-user.md` for public-facing tasks.

## Core Internal Model

- `Register` stores parallel per-slot arrays:
  - `traits`
  - `reprs`
  - `backgrounds`
  - `staterefs`
  - `stateindices`
  - `accesstimes`
  - `locks`
  - tag bookkeeping and network parent refs
- `StateRef` is the internal glue object:
  - `state::RefValue{Any}`
  - `registers`
  - `registerindices`
- `swap!`, `subsystemcompose`, `traceout!`, and `project_traceout!` all mutate backreferences. Review them as a consistency cluster, not as isolated functions.

## Invariants To Protect

- `staterefs[i]` and `stateindices[i]` must agree on whether a slot is assigned.
- `StateRef.registers` and `StateRef.registerindices` must always point back to the current owning slots.
- Operations must not move time backward. `apply!` and `uptotime!` throw on past-time requests.
- `RegisterNet` construction requires registers to share one simulation environment, or to still be unused at time zero so the constructor can rehome locks and tag waiters.
- Symbolic lowering for `apply!` and `observable` depends on the concrete state backend by the time state-level dispatch happens.

## Backend Extension Hooks

- `newstate(::QuantumStateTrait, ::AbstractRepresentation)`
- `apply!(state, subsystem_indices, operation)`
- `observable(state, subsystem_indices, obs)`
- `project_traceout!(state, stateindex, basis)`
- `traceout!(state, i)`
- `uptotime!(state, idx, background, dt)` and related methods
- `default_repr(...)`
- `consistent_representation(...)`

## Important Lowering Paths

- Symbolic initialization:
  - `initialize!(..., state::Symbolic)` -> `express(state, consistent_representation(...))`
- Register-level operations:
  - `apply!(regs, indices, ...)` -> `uptotime!` -> `subsystemcompose` -> backend `apply!`
- Register-level observables:
  - `observable(regs, indices, ...)` currently requires all touched slots to already share one `StateRef`
- Time evolution:
  - `uptotime!` groups by shared `StateRef` and prior access time before applying background updates

## Review Checks

- Confirm backreference integrity after composition, swap, measurement, and traceout.
- Check time monotonicity on every new code path that touches `accesstimes`.
- Look for user-facing code that reaches into `StateRef` or backend objects unnecessarily.
- Treat concurrent protocol bugs as register bugs first if locks are missing.
- Keep doc claims aligned with code. Current example: `docs/src/register_interface.md` describes cross-state observable composition more generally than `src/baseops/observable.jl` currently implements.
- Do not present `default_repr(::Qubit)` or `default_repr(::Qumode)` as a performance recommendation. They currently default to `QuantumOpticsRepr()`.

## Source Files To Read

- `src/states_registers.jl`
- `src/states_registers_networks_getset.jl`
- `src/networks.jl`
- `src/traits_and_defaults.jl`
- `src/baseops/initialize.jl`
- `src/baseops/apply.jl`
- `src/baseops/observable.jl`
- `src/baseops/traceout.jl`
- `src/baseops/subsystemcompose.jl`
- `src/baseops/uptotime.jl`
- `src/concurrentsim.jl`

## Tests To Anchor Behavior

- `test/general/register_interface_tests.jl`
- `test/general/registernet_interface_tests.jl`
- `test/general/apply_tests.jl`
- `test/general/observable_tests.jl`
- `test/general/project_traceout_tests.jl`

## Paper And Docs Cross-Check

- `docs/src/register_interface.md`
- `docs/src/modeling_registers_and_time.md`
- `docs/src/properties.md`
- `docs/src/architecture.md`
