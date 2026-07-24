# Protocol Development

- **Context need:** Task playbook
- **Open when:** Implementing or reviewing a resumable protocol where metadata or resource races matter.
- **Do not open when:** Looking up the shipped protocol catalog or changing transport without protocol behavior.
- **Related specification IDs:** SYS-004, SYS-005, SYS-008, SYS-009, SUB-013, CMP-012
- **Review when:** Protocol process structure, tag schemas, pair identifiers, resource locking, or cleanup rules change.

## Develop and review a protocol

1. Represent long-running behavior as a callable `AbstractProtocol` executed by a
   SimJulia process. Prefer the established shorthand constructor where applicable; it
   derives the simulation from the supplied `RegisterNet`, so do not maintain a
   second, potentially inconsistent simulation argument.
2. Declare the fixed tag payloads and slot ownership assumptions before coding. Use the
   standard tag types when they express the protocol fact. Pair identifiers deserve
   special review: the current combined identifier scheme can collide with the zero
   sentinel.
3. Treat every query result as a snapshot. `query_wait` is non-consuming and
   non-locking. After every yield and after resource acquisition, revalidate slot
   occupancy, reciprocal counterpart tags, pair identifiers, and any remote-node
   assumptions before mutation.
4. Keep exclusion windows small but sufficient. Acquire resources in a consistent
   order, re-check under ownership, and release on success, timeout, cancellation, and
   error. A notification means “something changed,” not “your match is reserved.”
5. Sequence physical and metadata effects consciously. State moves, traceout, tag
   deletion, and message send are not one atomic transaction. Define cleanup for every
   prefix of the sequence and do not assume an exception rolls it back.
6. Emit structured records using the stable `LOG_GROUPS.protocol` group and the
   protocol/simulation context helper. Treat individual event symbols and field sets as
   evolving unless a dedicated contract and tests establish stability.
7. Test adversarial interleavings, not only completion. Force stale query results,
   reciprocal-tag disagreement, occupied or emptied slots, competing consumers, and
   timeout cleanup. Run the relevant protocol tests plus the general shard.

The existing tracker, swapper, switch, cutoff, QTCP, and MBQC tests contain reusable
race patterns. Some zoo protocols remain incomplete, so copied behavior is evidence to
review, not automatically a requirement.

## Anchors

- **Source:** [`src/ProtocolZoo/ProtocolZoo.jl`](../../../src/ProtocolZoo/ProtocolZoo.jl), [`src/ProtocolZoo/entanglement_ids.jl`](../../../src/ProtocolZoo/entanglement_ids.jl), and [`src/querywait.jl`](../../../src/querywait.jl) — process, identifier, and wait seams.
- **Docs:** [`docs/src/discreteeventsimulator.md`](../../../docs/src/discreteeventsimulator.md) and [`docs/src/tutorial/myswapperprot.md`](../../../docs/src/tutorial/myswapperprot.md) — protocol construction walkthroughs.
- **Test:** [`test/general/protocolzoo_entanglement_tracker_lock_gap_tests.jl`](../../../test/general/protocolzoo_entanglement_tracker_lock_gap_tests.jl), [`test/general/protocolzoo_swapper_stale_query_tests.jl`](../../../test/general/protocolzoo_swapper_stale_query_tests.jl), and [`test/general/protocolzoo_entanglement_counterpart_invariant_tests.jl`](../../../test/general/protocolzoo_entanglement_counterpart_invariant_tests.jl) — race-focused examples.

## Unresolved questions

- Which cross-resource mutations should become library-supported transactions?
- How should pair identifiers avoid sentinel and composition collisions?
