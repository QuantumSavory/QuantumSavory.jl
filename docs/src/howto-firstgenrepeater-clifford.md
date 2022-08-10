# Clifford Simulations of First Generation Quantum Repeater

```@meta
DocTestSetup = quote
    using QuantumSavory
end
```

Here we will simulate a quantum repeater by employing a noisy Clifford circuit simulator.

Be sure to check out the more detailed tutorial on [wavefunction simulations of First Generation Quantum Repeater](@ref First-Generation-Quantum-Repeater) before proceeding with this one.

The changes we need to perform to the code are incredibly small. We only change the way the initial states of the entangled pairs are set, without changing any of the code implementing the swapping and purification steps. We can do that by first defining a function that generates noisy Bell states (by randomly returning either a good stabilizer tableau with probability `F` or a completely depolarized tableau with probability `1-F`).

```julia
const qc_perfect_pair = QuantumClifford.MixedDestabilizer(QuantumClifford.bell())
const qc_mixed = QuantumClifford.traceout!(copy(qc_perfect_pair), [1,2])
function qc_noisy_pair(F)
    if rand() < F
        return qc_perfect_pair
    else
        return qc_mixed
    end
end
```

We then use that in the entangler setup (the same way we used a similar function when we were doing wavefunction simulations):

```julia
# exerpt from `@resumable function entangler` in `firstgenrepeater_setup.jl`
        initialize!([registera,registerb],[ia,ib],noisy_pair(); time=now(sim))
```

For reference, here is the corresponding code for the wavefunction simulations:

```julia
b = QuantumOptics.SpinBasis(1//2)
l = QuantumOptics.spindown(b)
h = QuantumOptics.spinup(b)
qo_perfect_pair = (QuantumOptics.tensor(l,l) + QuantumOptics.tensor(h,h))/sqrt(2)
const qo_perfect_pair_dm = QuantumOptics.dm(qo_perfect_pair)
const qo_mixed = QuantumOptics.identityoperator(QuantumOptics.basis(qo_perfect_pair))/4
function qo_noisy_pair(F)
    F*qo_perfect_pair_dm + (1-F)*qo_mixed
end
```

## Simulation Trace

Similarly to the wavefunction simulations from the previous tutorial, here we can see how the various observables evolve over time for a Clifford-base simulation. Notice that unlike the wavefunction simulation, the results are very discrete, and we will certainly need to average over multiple repeated simulations of this trajectory.

```@raw html
<video src="../firstgenrepeater-08.clifford.mp4" autoplay loop muted></video>
```

## Comparison Against a Wavefunction-based Simulations

We can run the either simulation multiple times in order to compare the results from the wavefunction and tableau-based simulations:

![Comparison Against a Wavefunction-based Simulations](./firstgenrepeater-09.formalisms.png)

## Full Code

The entirety of the code necessary for reproducing these results is in the
[examples folder of the `QuantumSavory.jl` repository](https://github.com/Krastanov/QuantumSavory.jl/tree/master/examples/firstgenrepeater).