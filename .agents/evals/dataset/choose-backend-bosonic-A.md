Use `GabsRepr(...)` if the system is genuinely Gaussian.

That is the documented fit when:

- the modeled subsystems are bosonic modes;
- the state stays in the Gaussian regime;
- the operations are Gaussian; and
- continuous-variable measurements such as homodyne-style measurements are
  central to the model.

Use `QuantumOpticsRepr()` instead when you need a more general wavefunction or
operator-style simulation, including cases where the dynamics leave the
Gaussian regime or you want a more flexible reference calculation on smaller
instances.

The backend choice enters the model through the register representation:

```julia
using QuantumSavory

reg = Register(
    [Qumode()],
    [GabsRepr(QuadBlockBasis)],
)
```

You can also mix subsystem types and representations slot by slot:

```julia
reg = Register(
    [Qubit(), Qumode()],
    [QuantumOpticsRepr(), GabsRepr(QuadBlockBasis)],
)
```

If you leave the representation unspecified, the docs say `Qumode()` currently
defaults to `QuantumOpticsRepr()`, so use `GabsRepr(...)` explicitly when you
want the Gaussian backend.

