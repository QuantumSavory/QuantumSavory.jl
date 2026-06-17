# MySwapperProt tutorial

This example is a compact companion to the `MySwapperProt` sketch in the
QuantumSavory manuscript, available [here](https://arxiv.org/abs/2512.16752). It manually creates two Bell pairs, tags them
with `EntanglementCounterpart`, sends a swap request to the middle node, and
uses a small custom protocol to perform the local entanglement swap.

Run it with:

```julia
include("my_swapper_prot.jl")
```

