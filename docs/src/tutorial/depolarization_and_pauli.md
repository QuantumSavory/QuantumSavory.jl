# Depolarization and Pauli Noise

```@meta
DocTestSetup = quote
    using QuantumSavory
    using CairoMakie
end
```

TODO not finished and not included

Multi-qubit partial depolarization is the same as multi-qubit Pauli noise where each multi-qubit Pauli error has equal probability independent of its (Hamming) weight.

Single-qubit partial depolarization applied to qubit 1 and then single-qubit partial depolarization to qubit 2 is not the same as multi-qubit partial depolarization.