The documented reusable stack is:

1. Build one `RegisterNet` for the whole simulation.
2. Launch link-level entanglement generation with `EntanglerProt`.
3. Launch swapping at interior nodes with `SwapperProt`.
4. Add `EntanglementTracker` if your workflow depends on swap updates or
   deletion notices.
5. Add `CutoffProt` if old pairs should be discarded after a retention window.
6. Add an endpoint sink such as `EntanglementConsumer`, or your own consumer,
   at the places where long-range pairs are meant to be used.

That gives you a standard control-plane skeleton without rebuilding the whole
stack from scratch.

A minimal launch pattern looks like:

```julia
using QuantumSavory
using QuantumSavory.ProtocolZoo
using ConcurrentSim

sim = Simulation()
net = RegisterNet([Register(2), Register(2)])
prot = EntanglerProt(sim, net, 1, 2; rounds=-1)
@process prot()
```

Important composition rule: these protocols are designed to coordinate through
shared tags and message buffers, not hard-wired protocol-to-protocol calls.

If all you need is local quantum logic inside a larger custom protocol, use
`CircuitZoo` for that part and `ProtocolZoo` for the control flow around it.

The best concrete examples are:

- `docs/src/howto/firstgenrepeater_v2/firstgenrepeater_v2.md`
- `docs/src/howto/repeatergrid/repeatergrid.md`
- `examples/firstgenrepeater_v2/README.md`
- `examples/repeatergrid/README.md`

