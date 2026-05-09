The package is strong on state and metadata inspection, especially through
interactive visualization.

The main built-in debugging tools described in the docs are:

- `registernetplot_axis` for visualizing registers, occupied slots, and shared
  states;
- hover and click inspection of register contents;
- `showmetadata(...)` for forcing a metadata panel for a slot;
- `resourceplot_axis` for locks and graph-level metadata;
- and protocol-specific displays for some reusable protocols.

For live simulations, the plotting helpers return an observable-like update
handle, so you can `notify` the plot after advancing the simulation instead of
rebuilding it from scratch.

There is also a dedicated state-inspection workflow through the state explorer,
which is useful when you want to understand a predefined state family before
embedding it into a larger simulation.

What the docs emphasize less is a universal event-trace browser. The package
documentation is much stronger on:

- inspecting current quantum state structure;
- inspecting tags and messages;
- and visualizing protocol/resource state live.

So the short answer is:

- intermediate states and protocol metadata are fairly inspectable;
- live visual debugging is a first-class workflow;
- but if you want a generic event-log analysis tool, that is not the main thing
  the docs highlight.

