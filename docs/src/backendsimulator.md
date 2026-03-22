# [Backend Simulators](@id backend)

```@meta
DocTestSetup = quote
    using QuantumSavory
end
```

For help deciding which modeling approach to use, start with
[Choosing a Backend and Modeling Tradeoffs](@ref modeling-tradeoffs).

The simulation of quantum dynamics in QuantumSavory can be done through many
different backend simulators, depending on the tradeoff between performance,
generality, and physical system support that the user needs. By default, it
comes with two included simulators, `QuantumClifford` and `QuantumOptics`, but
other backends can be plugged in through the same register interface.

# QuantumClifford - Stabilizer Formalism

QuantumClifford leverages stabilizer states and Clifford gates — highly structured operations that can be simulated more efficiently than arbitrary quantum processes. It uses the tableaux formalism with the destabilizer improvements, as implemented in the [`QuantumClifford`](https://qc.quantumsavory.org/stable/) library. Simulations run in polynomial time, enabling very fast computations. However, adding non-Clifford elements breaks this efficiency, making the simulation more complex and slower.

# QuantumOptics - State Vector Formalism

QuantumOptics uses a fully general state vector (wavefunction) representation. This approach, provided by the ['QuantumOptics'](https://qojulia.org/) library, can handle any quantum operation or state without the structural restrictions of stabilizer methods. While this generality is powerful, it quickly becomes computationally expensive as the number of qubits grows — memory and time requirements scale exponentially. Consequently, simulating large systems with the state vector formalism becomes impractically slow compared to stabilizer-based methods.
