# QuantumSavory.jl

```@meta
DocTestSetup = quote
    using QuantumSavory
end
```

A multi-formalism simulator for noisy quantum communication and computation hardware with support for symbolic algebra, multiple simulation backends, a variety of noise models, discrete event simulation, optimization, and visualization.

### Capabilities

QuantumSavory offers features such as:

- **State, Circuit, and Protocols Zoos**: Collections of pre-built quantum states, circuits, and protocols to support rapid prototyping and application optimization.
- **Realistic Quantum Network Simulation**: : Support for simulating noise and decoherence effects.
- **Visualization**: Tools for visualizing register states and experiment metadata, with support for background maps.

The rest of the documentation is [structured](https://diataxis.fr/) as follows:

- [How-To Guides](@ref) - fully fleshed out guides to modeling common quantum hardware setups
- [Explanations](@ref) - how is the library structured, what are its conventions, and why were they decided upon
- [Tutorials](@ref) - examples covering a specific small feature of the library
- [References](@ref) - description of the entire library API

Depending on your learning style, you might prefer to start at different locations in the above documentation.

## Getting Started
### Installation
To use QuantumSavory, make sure you have Julia version 1.10 installed. You can download and install Julia from [the official Julia website](https://julialang.org/downloads/).

Once Julia is setup, QuantumSavory can be installed with the following command in your in your Julia REPL:
```bash
$ julia
julia> ]
pkg> add QuantumSavory
```
#### Optional Dependencies
There are optional packages that you need to install to use the full plotting feature.
- **Makie**: For plotting of registers and processes.
- **Tyler**: Enables plotting on a real-world map as a background.


### Basic Demo
Here’s a simple example to demonstrate how you can set up a simulation to generate a set of registers with qubit slots. For more advanced examples and detailed guide, see[How-To Guides](@ref) and [Tutorials](@ref) sections.



Below we show some of the results of the How-To guides.

#### A simulation of a quantum repeater:

```@raw html
<video src="howto/firstgenrepeater/firstgenrepeater-07.observable.mp4" autoplay loop muted></video>
```

#### A simulation of the generation of a cluster state in color-center memories:

```@raw html
<video src="howto/colorcentermodularcluster/colorcentermodularcluster-02.simdashboard.mp4" autoplay loop muted></video>
```

!!! warning

    This is a limited public demo of a fraction of some internal research code. Full code is slowly being documented and released.

!!! danger

    This is software is still in a fairly unstable alpha state! The documentation is extremely barebones and current users are expected to read the source code.

A good place to start is the How-To pages.
For instance, the [implementation of a first generation repeater](@ref First-Generation-Quantum-Repeater).

### Get Involved
We welcome contributions from experts and students alike, whether by improving the codebase or suggesting new useful features. Your input will help us refine QuantumSavory and support better quantum simulations. One way to get involved is through our bug bounty program — see [Bug Bounties Guide](https://github.com/QuantumSavory/.github/blob/main/BUG_BOUNTIES.md) for details.
