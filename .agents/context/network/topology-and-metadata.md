# Topology and Metadata

- **Context need:** Reference
- **Open when:** Looking up `RegisterNet` graph delegation, register indexing, or static vertex/edge metadata access.
- **Do not open when:** Changing channel delivery, protocol races, register state, or plotting implementation.
- **Related specification IDs:** SYS-006, SUB-007, CMP-007
- **Review when:** `RegisterNet` indexing, Graphs delegation, metadata storage, or dynamic-topology methods change.

## Graph and register access

`RegisterNet` wraps an undirected `SimpleGraph` and delegates `vertices`, `edges`,
`neighbors`, `adjacency_matrix`, `nv`, `ne`, and `add_vertex!` to it. Register access
is separate:

| Expression | Result |
|---|---|
| `net[i]` | Register at vertex `i` |
| `net[i, j]` | Slot `j` of register `i` |
| `net[:]` | Stored register vector |
| `net[:, j]` | Slot `j` from every register |

The last form assumes every register has that slot and otherwise propagates the indexing
error.

## Static metadata indexing

Vertex metadata uses `net[i, :key]`; `net[:, :key]` reads that key from every vertex.
Undirected edge metadata uses a tuple, `net[(i, j), :key]`, or a `SimpleEdge`. Tuple
endpoints are canonicalized with `minmax`, so `(i, j)` and `(j, i)` address the same
entry. Directed metadata is a separate store addressed by a pair:
`net[i => j, :key]` and `net[j => i, :key]` may differ.

Colon bulk access uses `net[(:, :), :key]` for undirected edges and
`net[(:) => (:), :key]` for directed edges. The directed form visits the orientation
returned by `edges(net)`; it does not return both directions. Bulk assignment accepts a
constant or a zero-argument function. A function is called once per vertex or edge, so
it is a value factory rather than a function value to store.

Metadata reads require the key to exist. Scalar edge setters create the per-edge
dictionary as needed; colon setters visit only current graph edges. The current
`(:) => (:)` setter loops over `SimpleEdge` values and therefore dispatches to the
undirected tuple store instead of the directed store; both its constant and function
forms are defective. Set directed metadata one ordered pair at a time.

## Construction boundary

Treat topology as static after `RegisterNet` construction. Construction sizes register,
metadata, channel, buffer, reverse-lookup, and naming structures together.
`add_vertex!(net)` changes only the wrapped graph. `add_register!` changes the graph and
register vector but leaves the other structures incomplete and currently computes an
invalid return value. Reconstruct a network instead of using either path for production
mutation.

## Anchors

- **Source:** [`src/states_registers_networks_getset.jl`](../../../src/states_registers_networks_getset.jl) and [`src/networks.jl`](../../../src/networks.jl) — graph delegation, indexing, metadata stores, and construction.
- **Docs:** [`docs/src/architecture.md`](../../../docs/src/architecture.md), [`docs/src/API.md`](../../../docs/src/API.md), and [`docs/src/visualizations.md`](../../../docs/src/visualizations.md) — public network model, generated API, and metadata consumers.
- **Test:** [`test/general/registernet_metadata_access_tests.jl`](../../../test/general/registernet_metadata_access_tests.jl) — register, graph, scalar, bulk, undirected, directed, and function-setter behavior.

## Unresolved questions

- Should dynamic topology be removed, completed, or made explicitly unsupported?
- Should directed bulk access enumerate both directions of every undirected edge?
