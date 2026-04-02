Use the explorer as a parameter-study tool, not just a viewer.

The documented starting point is:

```julia
using GLMakie
using QuantumSavory
using QuantumSavory.StatesZoo

stateexplorer(BarrettKokBellPairW)
```

What it shows for the current parameter choice:

- bar plots of the current two-qubit state in standard bases;
- summary figures of merit;
- one-parameter sweeps where one slider changes and the others stay fixed.

The recommended workflow is:

1. launch one state family;
2. move one slider at a time;
3. watch both the current-state plots and the corresponding sweep plot;
4. identify which parameters dominate fidelity or rate changes;
5. compare against another family if the first one is not a good surrogate.

Once a family looks appropriate, use the same family directly in the simulation:

```julia
reg = Register(2)
initialize!(reg[1:2], BarrettKokBellPairW(0.8, 0.8, 1e-6, 0.9, 0.95))
```

That is the main point of the explorer: it is inspecting the same reusable
state families that the rest of QuantumSavory consumes.

Useful follow-ups are `docs/src/tutorial/state_explorer.md`,
`docs/src/API_StatesZoo.md`, and `examples/state_explorer/README.md`.

