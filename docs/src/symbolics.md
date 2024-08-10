# Symbolic Expressions

```@meta
DocTestSetup = quote
    using QuantumSavory
end
```

`QuantumSavory` supports symbolic expressions for the quantum states and operations being simulated thanks to the `QuantumSymbolics` library. It serves two purposes:

- It provides for algebraic manipulation of mathematical expressions related to your models. Particularly helpful when having to automatically generate or simplify expressions of significant complexity.
- An assortment of "expression translators" are provided that can turn a symbolic expression into a numerical one in any of the representations supported by the simulator (e.g. wavefunctions, tableaux, etc).

Below we list some commonly used expressions. For more detailed documentation consult [`QuantumSymbolics.jl`](https://quantumsavory.github.io/QuantumSymbolics.jl/dev/).

```@setup symb
using QuantumSavory
```


```@raw html
<table>
<tr>
<th></th><th>Symbolic Example</th><th>Conversion Example</th>
</tr>
<tr>
```

```@raw html
<!-- Qubit Basis States -->
<td>
```
Qubit Basis States
`X1`, `X2`, `Y1`, `Y2`, `Z1`, `Z2`
```@raw html
</td>
<td>
```
```@example symb
Z1
```
```@raw html
</td>
<td>
```
```@example symb
express(Z1)
```
```@example symb
express(Y2, CliffordRepr())
```
```@raw html
</td>
</tr>
<tr>
```

```@raw html
<!-- Common gates -->
<td>
```
Common gates: `CNOT`, `H`, etc
```@raw html
</td>
<td>
```
```@example symb
CNOT
```
```@raw html
</td>
<td>
```
```@example symb
express(H)
```
```@example symb
express(CNOT, CliffordRepr(), UseAsOperation())
```
```@raw html
</td>
</tr>
<tr>
```

```@raw html
<!-- Tensor products and sums -->
<td>
```
Tensor products `⊗` and sums `+`
```@raw html
</td>
<td>
```
```@example symb
(X1⊗Z2 + Y1⊗Y2 ) / √3
```
```@raw html
</td>
<td>
```
```@example symb
express(X1⊗Z1)
```
```@example symb
express(X1⊗Y2, CliffordRepr())
```
```@raw html
</td>
</tr>
<tr>
```

```@raw html
<!-- Projectors -->
<td>
```
Projectors, pure density matrices
```@raw html
</td>
<td>
```
```@example symb
SProjector(X1⊗Z2)
```
```@raw html
</td>
<td>
```
```@example symb
express(SProjector(X1⊗Z1))
```
```@example symb
express(SProjector(X1⊗Z1), CliffordRepr())
```
```@raw html
</td>
</tr>
<tr>
```

```@raw html
<!-- Completely mixed state -->
<td>
```
Completely depolarized (mixed) state
```@raw html
</td>
<td>
```
```@example symb
MixedState(X1)
```
```@raw html
</td>
<td>
```
```@example symb
express(MixedState(X1))
```
```@example symb
express(MixedState(X1), CliffordRepr())
```
```@raw html
</td>
</tr>
<tr>
```

```@raw html
<!-- Mixtures -->
<td>
```
Impure states, represented as sum of density matrices
```@raw html
</td>
<td>
```
```@example symb
(MixedState(X1)+SProjector(Z1)) / 2
```
```@raw html
</td>
<td>
```
```@example symb
express((MixedState(X1)+SProjector(Z1)) / 2)
```
When a Clifford representation is used, an efficient sampler is generated, and stabilizer states are randomly sampled from the correct distribution:
```@example symb
express(MixedState(X1)/2+SProjector(Z1)/2, CliffordRepr())
```
```@raw html
</td>
</tr>
<tr>
```

```@raw html
</tr>
</table>
```

!!! warning "Stabilizer state expressions"

    The state written as $\frac{|Z₁⟩⊗|Z₁⟩+|Z₂⟩⊗|Z₂⟩}{√2}$ is a well known stabilizer state, namely a Bell state. However, automatically expressing it as a stabilizer is a prohibitively expensive computational operation in general. We do not perform that computation automatically. If you want to ensure that states you define can be automatically converted to tableaux for Clifford simulations, avoid using summation of kets. On the other hand, in all of our Clifford Monte-Carlo simulations, `⊗` is fully supported, as well as `SProjector`, [`MixedState`](@ref), [`StabilizerState`](@ref), and summation of density matrices.