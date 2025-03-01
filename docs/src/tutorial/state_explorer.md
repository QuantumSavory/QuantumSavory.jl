# Interactively visualizing two-qubit states

The [`QuantumSavory.StatesZoo.stateexplorer`](@ref) routine lets you generate an interactive state visualizer, **that can also be used as an input state in interactive live simulations**.

E.g. take the Barrett-Kok dual-rail heralded entanglement procedure -- it produces a state that is available from [`QuantumSavory.StatesZoo`](@ref Predefined-Models-of-Quantum-States) as [`BarrettKokBellPairW`](@ref). The following is enough to generate the interactive `Makie` figure:

```julia
stateexplorer!(fig, BarrettKokBellPairW)
```

Below we embed a live version of this state explorer (hosted at [areweentangledyet.com/state_explorer/](https://areweentangledyet.com/state_explorer/)):

```@raw html
<iframe src="https://areweentangledyet.com/state_explorer/" style="height:600px;width:850px;"></iframe>
```

The source code is in the [`examples/state_explorer`](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/state_explorer) folder.