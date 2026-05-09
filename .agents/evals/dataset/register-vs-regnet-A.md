Use `Register` when you are modeling one local hardware container. Use
`RegisterNet` when multiple registers participate in one simulation and you
care about shared time, channels, or message buffers.

The idiomatic split is:

- `Register`
  - local collection of slots;
  - each slot can have its own subsystem trait, preferred representation, and
    background process;
  - the normal public handle is `reg[i]`, a `RegRef`.
- `RegisterNet`
  - graph-backed collection of registers;
  - shared simulation context and time tracking;
  - access to classical channels, message buffers, and network quantum
    channels.

If a set of registers will participate in one network simulation, the
user-facing guidance is to use `RegisterNet` early rather than building several
independent `Register`s and stitching them together later.

Typical local use:

```julia
reg = Register([Qubit(), Qubit()])
initialize!(reg[1:2], StabilizerState("XX ZZ"))
```

Typical network use:

```julia
net = RegisterNet([Register(2), Register(2)]; classical_delay=1.0, quantum_delay=5.0)
initialize!((net[1, 1], net[2, 1]), StabilizerState("XX ZZ"))
```

If you expect protocols, delays, or messaging, `RegisterNet` is the right
default.

