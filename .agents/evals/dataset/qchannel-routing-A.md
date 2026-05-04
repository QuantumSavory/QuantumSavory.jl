No. `qchannel(net, ...)` is documented as a direct-edge quantum link, not an
automatic multihop repeater or routing layer.

The routing feature belongs to the classical side:

- `channel(net, src => dst; permit_forward=true)` can forward classical `Tag`
  messages across the graph;
- that forwarding computes a shortest path and re-emits the message hop by hop.

That behavior does not imply any corresponding multihop quantum transport.

If you want end-to-end quantum connectivity across several hops, the documented
approach is to build it at the protocol layer, typically with components such
as:

- `EntanglerProt` for link-level pairs,
- `SwapperProt` for local swaps,
- `EntanglementTracker` for metadata coherence,
- and optionally `CutoffProt` for stale-pair cleanup.

So the short answer is:

- classical forwarding exists;
- automatic quantum multihop transport does not.

