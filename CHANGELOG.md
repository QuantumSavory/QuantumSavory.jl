# News
- Rich text, HTML, and PNG displays for register states now summarize small QuantumOpticsBase states (Bloch vector, purity, entropy, density matrix, top basis probabilities) and QuantumClifford stabilizer states.

## v0.7.1 - unreleased

- Additional visualization methods for states of registers.

## v0.7.0 - 2026-06-12

- **(breaking)** **(fix)** The `ProtocolZoo` entanglement-tracking tags and messages now carry entanglement pair IDs, fixing a class of bookkeeping bugs (#303) where stale update messages could be applied to the wrong Bell pair after a physical slot was reused. See the porting guide below.
- **(fix)** `EntanglementTracker` no longer waits on the physical slot lock when an incoming update only needs `EntanglementHistory` metadata of an empty slot, fixing a race (#448) where valid in-flight updates were dropped as stale because history forwarding was serialized behind slot reuse by an `EntanglerProt`.
- `SwapperProt` gained a `max_history_per_slot` option and `CutoffProt` gained a `max_delete_per_slot` option, enforcing FIFO caps on accumulated `EntanglementHistory` and `EntanglementDelete` metadata. `CutoffProt` no longer deletes old `EntanglementHistory` tags itself; history cleanup is now owned by the swapper that creates those tags.
- Stale update/delete messages dropped by `EntanglementTracker` are now logged at `@warn` level instead of `@error`, as with pair IDs such drops are expected only under benign circumstances (e.g. history garbage collection).

### Porting guide for the pair-ID tag schema

User code that creates, queries, or destructures the `ProtocolZoo` entanglement tags needs the following updates. The new ID fields are of type `EntanglementID` (an alias for `Int`), with `NO_ENTANGLEMENT_ID == 0` reserved as the neutral/legacy value; fresh IDs are created with `fresh_entanglement_id()` and swap composition uses `combine_entanglement_ids(a, b)`.

The tag schemas changed as follows (new fields in **bold**):

| Tag | Old schema | New schema |
|---|---|---|
| `EntanglementCounterpart` | `(remote_node, remote_slot)` | `(remote_node, remote_slot, `**`pair_id`**`)` |
| `EntanglementHistory` | `(remote_node, remote_slot, swap_remote_node, swap_remote_slot, swapped_local)` | `(remote_node, remote_slot, swap_remote_node, swap_remote_slot, swapped_local, `**`local_chunk_id`**`, `**`swapped_chunk_id`**`)` |
| `EntanglementUpdateX` / `EntanglementUpdateZ` | `(past_local_node, past_local_slot, past_remote_slot, new_remote_node, new_remote_slot, correction)` | `(`**`target_pair_id`**`, `**`other_pair_id`**`, past_local_node, past_local_slot, past_remote_slot, new_remote_node, new_remote_slot, correction)` |
| `EntanglementDelete` | `(send_node, send_slot, rec_node, rec_slot)` | `(`**`target_pair_id`**`, send_node, send_slot, rec_node, rec_slot)` |

Required changes, in decreasing order of likelihood that they affect you:

1. **Queries must use the new arity.** A query with the old number of fields *silently matches nothing* — it does not error. Add a wildcard for the new field(s), e.g.
   - `query(reg, EntanglementCounterpart, node, ❓)` → `query(reg, EntanglementCounterpart, node, ❓, ❓)`
   - `queryall(reg, EntanglementHistory, ❓, ❓, ❓, ❓, ❓)` → `queryall(reg, EntanglementHistory, ❓, ❓, ❓, ❓, ❓, ❓, ❓)`
   - `querydelete!(mb, EntanglementUpdateX, ❓, ❓, ❓, ❓, ❓, ❓)` → `querydelete!(mb, EntanglementUpdateX, ❓, ❓, ❓, ❓, ❓, ❓, ❓, ❓)`
2. **Raw `tag!` and `Tag` calls must include the new fields.** `tag!(slot, EntanglementCounterpart, node, slot_idx)` still runs, but creates an old-arity tag that is *invisible* to all queries and protocols in this release. Write `tag!(slot, EntanglementCounterpart, node, slot_idx, pair_id)` instead, where `pair_id` comes from `fresh_entanglement_id()` for a new pair (use the same ID on both ends of the pair), or `NO_ENTANGLEMENT_ID` for metadata that does not participate in ID-based tracking.
3. **Positional destructuring of update/delete messages must shift indices.** The two ID fields are *prepended* to `EntanglementUpdateX`/`EntanglementUpdateZ` and one ID field is prepended to `EntanglementDelete`, so e.g. `tag[2]` (formerly `past_local_node` / `send_node`) is now `tag[4]` / `tag[3]`. `EntanglementCounterpart` and `EntanglementHistory` are extended at the end, so existing indices keep working there.
4. **The struct constructors are backward compatible.** `EntanglementCounterpart(node, slot)`, `EntanglementHistory(a, b, c, d, e)`, `EntanglementUpdateX(a, b, c, d, e, f)`, and `EntanglementDelete(a, b, c, d)` still work and fill the new fields with `NO_ENTANGLEMENT_ID`. Note however that protocols match counterpart tags by exact pair ID, so hand-constructed `NO_ENTANGLEMENT_ID` metadata only interoperates with other legacy-ID metadata.
5. **Reciprocal tags must agree on the pair ID.** `EntanglementConsumer` (and the switch protocols) now require the two ends of a pair to carry the same `pair_id` in their reciprocal `EntanglementCounterpart` tags, not just matching `(node, slot)` routing info. If you create entangled pairs manually in tests or examples, tag both ends with the same ID.
6. **Custom tag types are unaffected.** `EntanglerProt(...; tag=MyTag)` keeps writing the legacy two-field `MyTag(remote_node, remote_slot)` schema, and `EntanglementConsumer(...; tag=MyTag)` keeps querying it with the legacy arity. Only `EntanglementCounterpart` carries a pair ID.
- **(fix)** Solving edge cases of deadlocks when simultaneously tagging and waiting on tags.
- Significant performance improvements to queries on registers or buffers that already contain many tags.
- New QTCP tutorial examples under `examples/qtcp_tutorial/` demonstrating basic usage on a chain, GLMakie visualization, multi-flow on a grid topology, and custom endpoint controllers.

## v0.6.0 - 2026-05-05

- **(breaking)** Some fields of EntanglerProt were renamed for consistency with other protocols. More such renaming is to be expected, for consistency's sake.
- **(breaking)** The `StatesZoo` now integrates with the `Genqo.jl` package, to provide high accuracy models of the ZALM entanglement source. The previous implementation of the ZALM source was removed.
- **(breaking)** Renaming `wait(::MessageBuffer)` and `onchange_tag(::Register)` to `onchange`.
- **(fix)** `observable` used to incorrectly handle subsystem permutations on some backends in some edge cases, giving wrong results.
- **(fix)** Stale `EntanglementDelete` messages in `EntanglementTracker` are now dropped as a workaround for protocol bookkeeping issue #303.
- **(fix)** Tensor products of operators are now better supported in `apply!` for `CliffordRepr`
- Querying functions now also return the time at which a tag was tagged.
- `query_wait` now exists as a much simpler alternative to `onchange` followed by `query`.
- `GraphStateConstructor` protocol and related tooling for modeling of the iterative construction of a graph state out of Bell pairs.
- Protocol constructors moving to having constructors that do not require `sim` to be explicitly specified.
- Noise types now have default parameters, for ease of construction in examples. The default values generally correspond to near-zero noise (e.g. decoherence time of `1e9`).
- Protocols (subtypes of `AbstractProtocol` in the `ProtocolZoo`) now have rich `show` methods for the `image/png` and `text/html` MIME types
- Unexported function `permits_virtual_edge` to describe whether a protocol can run between two nodes that are not directly connected.
- Non-public functions `parent`, `parentindex`, `name`, `namestr`, `timestr`, `compactstr`,  `available_protocol_types`, `available_slot_types`, `available_background_types`, `constructor_metadata` for better introspection capabilities and cleaner printing.
- `T1T2` noise has been added.
- Support for Gaussian states, unitaries, and channels through `GabsRepr` as the default for QModes.
- `HomodyneMeasurement` has been added for Gaussian-state measurements.
- New assisted continuous-variable teleportation example.
- New piecemaker GHZ-switch example.
- `DepolarizedBellPair` added to `StatesZoo`, representing a depolarized Bell state `p|Φ⁺⟩⟨Φ⁺| + (1-p)I/4`, constructible from either the depolarization parameter `p` or fidelity `F`.

## v0.5.1 - 2025-07-14

- Add `classical_delay` and `quantum_delay` as keyword arguments to the `RegisterNet` constructor to set a default global network edge latency.
- `onchange_tag` now permits a protocol to wait for any change to the tag metadata.
- Plots of networks can now overlay real-world maps (see `generate_map`).
- A "state explorer" tool was added to the plotting submodule and as an interactive example, to heal visualize many of the states in StatesZoo.
- Additional filtering and decision capabilities in `EntanglerProt`.
- Fixes and additions to available background noise processes.
- Rebuilding the ZALM source from StatesZoo in a more reproducible fashion.
- Fixes and performance improvements to `observable`.
- New examples related to preparing GHZ states and MBQC-based purification.
- The switch protocol is now back to fully functional, thanks to an upstream fix in GraphsMatching.jl.

## v0.5.0 - 2024-10-16

- Develop `CutoffProt` to deal with deadlocks in a simulation
- Expand `SwapperProt` with `agelimit` to permit cutoff policies (with `CutoffProt`)
- Tutorial and interactive examples for entanglement distribution on a grid with local-only knowledge
- **(breaking)** `observable` now takes a default value as a kwarg, i.e., you need to make the substitution `observable(regs, obs, 0.0; time)` ↦ `observable(regs, obs; something=0.0, time)`
- Bump QuantumSymbolics and QuantumOpticsBase compat bound and bump julia compat to 1.10.
- Implement a simple switch protocol.
    - Simplify one of the switch protocols to avoid dependence on GraphsMatching.jl. which does not install well on non-linux systems. Do not rely on the default `SimpleSwitchDiscreteProt` for the time being.

## v0.4.2 - 2024-08-13

- Incorrect breaking release. It should have been 0.5 (see above).

## v0.4.1 - 2024-06-05

- Significant improvements to the performance of `query`.

## v0.4.0 - 2024-06-03

- Establishing `ProtocolZoo`, `CircuitZoo`, and `StateZoo`
- Establishing `Register`, `RegRef`, and `RegisterNet`
- Establishing the symbolic expression capabilities
- Establishing plotting and visualization capabilities

## older versions were not tracked
