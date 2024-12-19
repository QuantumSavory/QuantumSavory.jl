# [Discrete Event Simulator](@id sim)

```@meta
DocTestSetup = quote
    using QuantumSavory
end
```

## Overview

Simulating quantum processes requires robust tools for **Discrete Event Simulation**. In QuantumSavory, we use `ConcurrentSim.jl` and `ResumableFunctions.jl` to model complex, asynchronous processes.

This simulation framework enables protocols to handle dynamic interactions, such as waiting for resources to become available.

### **ConcurrentSim.jl** and **ResumableFunctions.jl**

QuantumSavory discrete event simulations are based on [`ConcurrentSim.jl`](https://github.com/JuliaDynamics/ConcurrentSim.jl). A process is defined as a `@resumable` function that yields events, allowing for efficient resource allocation and the expression of protocols that pause until specific conditions are met. These features are essential for implementing waiting mechanisms, such as waiting for messages or changes in a quantum state.
