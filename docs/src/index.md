# QuantumSavory.jl

```@meta
DocTestSetup = quote
    using QuantumSavory
end
```

A multi-formalism simulator for noisy quantum communication and computation hardware with support for symbolic algebra, multiple simulation backends, a variety of noise models, discrete event simulation, optimization, and visualization.

We are also preparing a [getting started manual](/manual).

The rest of the documentation is [structured](https://diataxis.fr/) as follows:

- [How-To Guides](@ref) - fully fleshed out guides to modeling common quantum hardware setups
- [Explanations](@ref) - how is the library structured, what are its conventions, and why were they decided upon
- [Tutorials](@ref) - examples covering a specific small feature of the library
- [References](@ref) - description of the entire library API

Depending on your learning style, you might prefer to start at different locations in the above documentation.

Below we demo some of the results of the How-To guides.

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