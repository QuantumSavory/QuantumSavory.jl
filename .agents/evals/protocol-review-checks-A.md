The main contributor guidance boils down to a small checklist.

Basic structure:

- subtype `AbstractProtocol`;
- store `sim` and `net` in the object;
- implement `@resumable function (prot::MyProt)()`;
- reuse existing tag and message schemas when possible.

The main review checks are:

- verify lock acquisition and release on every path;
- check whether the protocol only behaves correctly when paired with
  `EntanglementTracker`;
- treat field-position access like `tag[2]` or `tag[3]` as brittle hotspots;
- for tracker-related behavior, cross-check nonzero `classical_delay`,
  `CutoffProt.retention_time`, and `SwapperProt.agelimit`;
- keep shorthand constructors aligned with the existing validation coverage;
- if the protocol intentionally works across non-physical edges, define
  `permits_virtual_edge(::MyProt) = true`.

The shared schemas explicitly called out for reuse are:

- `EntanglementCounterpart`
- `EntanglementHistory`
- `EntanglementUpdateX`
- `EntanglementUpdateZ`
- `EntanglementDelete`

Areas worth treating as anchors are the existing checks around entanglers,
trackers, cutoff behavior, swapper slot choice, switches, QTCP, and virtual
edges.

So the high-level rule is: review concurrency, metadata contracts, and tracker
interactions first. Those are the places where subtle protocol bugs tend to
hide.
