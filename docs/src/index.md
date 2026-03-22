# QuantumSavory.jl

```@meta
DocTestSetup = quote
    using QuantumSavory
end
```

A multi-formalism simulator for noisy quantum communication and computation
hardware, with support for symbolic algebra, multiple simulation backends,
noise models, discrete-event simulation, optimization, and visualization.

## Start Here

If this is your first visit, the shortest path is:

1. Install the package with `pkg> add QuantumSavory`.
2. Work through the [Getting Started Manual](@ref manual).
3. Continue into [Explanations](@ref), [Tutorials](@ref), [How-To Guides](@ref),
   or [References](@ref), depending on what you need next.

## Documentation Map

- [Getting Started Manual](@ref manual): a first guided simulation.
- [Explanations](@ref): architecture, conventions, and the conceptual model.
- [Tutorials](@ref): focused lessons on one feature at a time.
- [How-To Guides](@ref): larger task-oriented workflows.
- [References](@ref): API lookup and generated module documentation.

## Capabilities

QuantumSavory is particularly useful when you want to combine:

- symbolic descriptions of states and operations,
- interchangeable numerical backends,
- explicit noise and time evolution,
- classical control for LOCC-style protocols, and
- visualization of states, metadata, and protocol state.

## Example Applications

Below we show some of the results of the How-To guides.

#### A simulation of a quantum repeater:

```@raw html
<video src="howto/firstgenrepeater/firstgenrepeater-07.observable.mp4" autoplay loop muted></video>
```

#### A simulation of the generation of a cluster state in color-center memories:

```@raw html
<video src="howto/colorcentermodularcluster/colorcentermodularcluster-02.simdashboard.mp4" autoplay loop muted></video>
```

For a first runnable example, start with the [Getting Started Manual](@ref manual).

## Office Hours

Office hours are held every Friday from 12:30 – 1:30 PM Eastern Time via [Zoom](https://umass-amherst.zoom.us/j/95986275946?pwd=6h7Wbai1bXIai0XQsatNRWaVbQlTDr.1). Before joining, make sure to check the [Julia community events calendar](https://julialang.org/community/#events) to confirm whether office hours are happening, rescheduled, or canceled for the week. Feel free to bring any questions or suggestions!

## Support

QuantumSavory.jl is developed by [many volunteers](https://github.com/QuantumSavory/QuantumSavory.jl/graphs/contributors), managed at [Prof. Krastanov's lab](https://lab.krastanov.org/) at [University of Massachusetts Amherst](https://www.umass.edu/quantum/).

The development effort is supported by The [NSF Engineering and Research Center for Quantum Networks](https://cqn-erc.arizona.edu/), and
by NSF Grant 2346089 "Research Infrastructure: CIRC: New: Full-stack Codesign Tools for Quantum Hardware".

## Bounties

[We run many bug bounties and encourage submissions from novices (we are happy to help onboard you in the field).](https://github.com/QuantumSavory/.github/blob/main/BUG_BOUNTIES.md)
