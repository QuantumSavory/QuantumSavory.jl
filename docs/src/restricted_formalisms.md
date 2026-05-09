# [Restricted Formalisms and Efficient Simulation](@id restricted-formalisms)

Generic quantum simulation gets expensive very quickly. That is why practical
work often depends on restricted formalisms: you give up some generality in
exchange for much faster simulation on the kinds of states and operations you
actually need.

## Stabilizer Simulation

Stabilizer methods are a good fit when the model stays close to Clifford gates,
Pauli measurements, and Pauli-like noise.

That covers many useful workloads:

- Bell-pair generation and swapping
- repeater-style protocols
- syndrome extraction and related error-correction tasks

When the model fits this regime, stabilizer simulation can be dramatically
faster than a general wavefunction method.

## Gaussian Simulation

Gaussian methods are a good fit when the subsystems are bosonic modes and the
states and operations stay in the Gaussian regime.

This is especially useful for optical and continuous-variable models. Instead
of forcing those systems into an awkward qubit-only approximation, you can use
a representation that matches the physics and still scales well.

## Tensor Networks

Tensor-network methods try to compress the state by exploiting entanglement
structure. They are useful when the important correlations stay limited or
well-structured.

They are not yet a first-class backend in QuantumSavory, but they fit the same
overall architecture: keep the model, change the numerical representation.

## Finite-Rank and Near-Clifford Methods

Between exact stabilizer simulation and fully general simulation there is a
middle ground. Near-Clifford and finite-rank methods aim to keep most of the
speed of stabilizer simulation while allowing a limited amount of non-Clifford
behavior.

These methods are also not first-class options in QuantumSavory yet, but they
matter because they show that backend choice is not only "fast but restricted"
versus "slow but general". There is often a useful middle range.

## Why This Matters In QuantumSavory

QuantumSavory separates symbolic modeling from backend choice so you can take
advantage of these methods without rewriting the whole simulation each time you
change representation. That is the main productivity win: the model stays
stable while the numerical strategy changes.

## Where To Go Next

- Read [Choosing a Backend and Modeling Tradeoffs](@ref modeling-tradeoffs) for
  the backend choices currently exposed in QuantumSavory.
- Read [Properties](@ref) and [Background Noise Processes](@ref) to connect
  these simulation choices back to the physical system being modeled.
