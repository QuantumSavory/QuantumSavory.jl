# Discrete Events

- **Context need:** Explanation
- **Open when:** Reasoning about ConcurrentSim processes, waits, resource ownership, or event ordering.
- **Do not open when:** Looking up register operations, backend methods, or zoo inventory.
- **Review when:** Simulation-process helpers, resource acquisition, notifier behavior, or wait composition changes.

## Scheduling model

QuantumSavory coordinates long-running behavior with ConcurrentSim discrete-event
processes. A process runs until it yields an event, resumes when that event fires, and
shares one simulation clock with registers and network delays. Code between yields is
the practical atomic region; any snapshot retained across a yield may be stale when
execution resumes.

Resources serialize access where a protocol must exclude competitors. Acquire only the
resources required for the imminent action, re-check all conditions after acquisition,
and release them on every modeled completion, timeout, or cancellation path. A thrown
exception abandons the simulation rather than promising resource recovery. A tag match
or notification alone is not ownership: another process can consume metadata, trace
out a slot, or replace state before this process next runs.

Metadata and message waits are change-driven loops. `query_wait` queries before
blocking, waits on `ChangeNotifier` when no candidate matches, and queries again after
waking. It never consumes or reserves a result; `querydelete_wait!` is the consuming
variant. Register changes use a register-wide notifier; a wake says that something
changed, not that a particular predicate is now true. Message-buffer notification uses
the same primitive with queued buffer wake tokens, so implementations must tolerate
redundant or coalesced wakeups.

Time progression comes from yielded timeout or channel events, not wall-clock delay.
Network directional delay functions schedule arrivals on the same simulation.
Register `NonInstantGate` and `ConstantHamiltonianEvolution` calls are instead
synchronous: they update slot access times without yielding or moving the scheduler
clock; see [time and noise](../simulation/time-and-noise.md). Avoid manually changing
simulation time.

Identical simulated timestamps do not establish relative order between independent
events or processes. Any tie-breaking observed from ConcurrentSim, including apparent
insertion order, is an implementation detail that may change with future ConcurrentSim
versions. When order matters, encode a causal dependency with an awaited event,
message, resource handoff, or distinct simulated time. The notification guarantees
below depend on which waiters are already registered when a change occurs, not on a
general equal-time ordering rule.

Race-oriented tests should force yields between selection and mutation, then verify
revalidation and cleanup. The protocol tracker, swapper, switch, and cutoff suites
contain examples of stale-query and reciprocal-tag failures that are more informative
than straight-line happy paths.

## Anchors

- **Source:** [`src/semaphore.jl`](../../../src/semaphore.jl), [`src/querywait.jl`](../../../src/querywait.jl), and [`src/concurrentsim.jl`](../../../src/concurrentsim.jl) — notification, wait-loop, and simulation helpers.
- **Docs:** [`docs/src/discreteeventsimulator.md`](../../../docs/src/discreteeventsimulator.md) and [`docs/src/modeling_registers_and_time.md`](../../../docs/src/modeling_registers_and_time.md) — human-facing event and time model.
- **Test:** [`test/general/concurrentsim_helpers_tests.jl`](../../../test/general/concurrentsim_helpers_tests.jl), [`test/general/semaphore_tests.jl`](../../../test/general/semaphore_tests.jl), and [`test/general/protocolzoo_entanglement_tracker_lock_gap_tests.jl`](../../../test/general/protocolzoo_entanglement_tracker_lock_gap_tests.jl) — scheduling and race evidence.

## Unresolved questions

- Should resource-safe cleanup helpers become a shared protocol abstraction?
