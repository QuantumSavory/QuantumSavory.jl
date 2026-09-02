# [Choose `EntanglerProt.margin` to Avoid Deadlocks](@id tutorial-entangler-margin)

[`EntanglerProt`](@ref) will occupy every free slot on a pair of registers
unless you tell it not to. The default `margin = 0` means "keep generating as
long as any slot is empty". That is fine when this entangler is the only user
of those slots — for example a dedicated link plus an
[`EntanglementConsumer`](@ref) that frees them. It deadlocks as soon as
another protocol needs a slot on the same register: a neighboring link's
entangler, or a [`SwapperProt`](@ref) that needs one pair on each side of a
repeater.

## What the numbers actually do

Each round, `EntanglerProt` calls [`findfreeslot`](@ref) with a margin:

- `hardmargin` while this pair of nodes has **no** entanglement yet,
- `margin` once at least one pair already exists.

`findfreeslot` returns `nothing` when the register currently has fewer than
that many unassigned slots. After a successful generation, at least
`margin - 1` slots remain empty (for `margin ≥ 1`). So:

| value | effect |
| --- | --- |
| `margin = 0` (default) | fill every slot; other protocols starve |
| `margin = 1` | same as `0`: the last empty slot can still be taken |
| `margin ≥ 2` | keep at least `margin - 1` slots empty once this link already has a pair |

`hardmargin` is usually left at `0` so the first pair on a link can still form
when the register is almost full. After that first pair exists, `margin` takes
over. A typical repeater recipe is `hardmargin = 0` and `margin ≥ 2`.

## Count occupied slots

On a pair of 3-slot registers the occupancy is deterministic. With
`hardmargin = 0` the first pair always forms; `margin` then decides how many
more the same entangler is allowed to take.

```@example entangler_margin
using QuantumSavory
using QuantumSavory.ProtocolZoo
using ConcurrentSim

function occupied(margin)
    net = RegisterNet([Register(3), Register(3)])
    sim = get_time_tracker(net)
    @process EntanglerProt(sim, net, 1, 2;
        success_prob=1.0, attempt_time=0.01, retry_lock_time=0.01,
        rounds=-1, margin, hardmargin=0)()
    run(sim, 1.0)
    count(i -> isassigned(net[1][i]), 1:3)
end

occupied.([0, 1, 2, 3])
```

The result is `[3, 3, 2, 1]`: defaults fill the register, `margin = 2` leaves
one slot free, and `margin = 3` leaves two.

## Why a repeater deadlocks at the default

A 3-node chain with two slots per node is the smallest picture of the failure
mode. If the `1—2` entangler runs first with `margin = 0`, it fills **both**
slots of the middle node with `1—2` pairs. The `2—3` entangler then never
finds a free slot, the swapper at node 2 never sees a high-side pair, and an
end-to-end [`EntanglementConsumer`](@ref) records nothing.

```julia
net = RegisterNet([Register(2) for _ in 1:3])
sim = get_time_tracker(net)
entangler_kwargs = (; success_prob=1.0, attempt_time=0.01, retry_lock_time=0.01, rounds=-1)

# Default margin=0 fills both slots of node 2 with 1—2 pairs.
@process EntanglerProt(sim, net, 1, 2; entangler_kwargs...)()
run(sim, 0.5)

# Starting the rest of the stack cannot recover: node 2 has no free slot.
@process EntanglerProt(sim, net, 2, 3; entangler_kwargs...)()
@process SwapperProt(sim, net, 2; nodeL=<(2), nodeH=>(2), chooseL=argmin, chooseH=argmax)()
for v in 1:3
    @process EntanglementTracker(sim, net, v)()
end
consumer = EntanglementConsumer(sim, net, 1, 3; period=0.05)
@process consumer()
run(sim, 2.0)
# length(consumer._log) == 0
```

The same stack with `margin = 2, hardmargin = 0` on **both** entanglers does
make end-to-end pairs: each link is allowed its first pair (`hardmargin = 0`),
then stops before taking the last slot (`margin = 2`), so the swapper can
fire and free the slots for the next round.

```julia
entangler_kwargs = (; success_prob=1.0, attempt_time=0.01, retry_lock_time=0.01,
                     rounds=-1, margin=2, hardmargin=0)
```

The in-tree consumer tests use the same idea on larger registers:
`margin=5, hardmargin=3` on 10-slot nodes, which keeps several slots free for
swapping along the chain.

## How to pick the numbers

- Count how many *other* protocols need a free slot on the same register
  (neighboring entanglers, swappers, purifiers, QTCP link controllers).
- Set `margin` to one more than the number of slots you must keep empty once
  this link already has entanglement. Keeping one slot free is `margin = 2`.
- Leave `hardmargin = 0` unless you must reserve space even for the first
  pair. That is rare on a dedicated two-node link and more relevant when many
  links share a large register — the QTCP external-inventory example uses
  `margin=18, hardmargin=10`.
- If this entangler is the only occupant and a consumer frees slots, the
  default `0` is acceptable.

[`CutoffProt`](@ref) is a complementary safety net (it drops stale qubits) but
does not replace `margin`: a live pair still occupies a slot.

## Carry forward

- Default `margin = 0` monopolizes registers and can deadlock swappers.
- `findfreeslot` requires at least `margin` currently empty slots, so
  `margin = 1` still fills the last slot.
- Repeater nodes: `hardmargin = 0`, `margin ≥ 2`.
