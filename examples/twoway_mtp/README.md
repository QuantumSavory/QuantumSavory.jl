# Two-way Multiplexed Protocol

This example demonstrates a high-performance simulation of a multiplexed two-way quantum repeater architecture based on the protocol outlined in [Mantri et al., 2024](https://arxiv.org/abs/2409.06152). It models entanglement generation, DEJMPS purification on a schedule, and entanglement swapping under realistic noise, leveraging QuantumSavory.jl’s flexible architecture.

## Overview
This simulation models a linear quantum network consisting of:
- A sender (Alice), a receiver (Bob), and one or more intermediate Repeaters
- Multiplexed imperfect Bell pair generation on each link
- A realistic noise model involving T2 decoherence, gate errors and measurement infidelity

The experiment aims to evaluate:
- End-to-end fidelity after purification and swapping
- Secret Key Rate (SKR) across different configurations

![SimGIF](https://pouch.jumpshare.com/preview/DC3f7WLV8MZBij8oZZJzsy3wfS5RCLIgpxfLik0SPj12KPPdBe-5SZOvvPgGz_iPxHIA3sErGJ_1XUOG1nWkWrem2COdyPx78xsPzwhcFZA)

## Running the simulation
Clone the repository and install the necessary dependencies:
```sh
git clone https://github.com/QuantumSavory/QuantumSavory.jl.git
julia --project=examples -e "using Pkg; Pkg.instantiate()"
```

Run one of the example simulations:
```sh
julia --project=examples ./examples/twoway_mtp/n_example.jl
```

## References
- Mantri, P., Goodenough, K., & Towsley, D. (2024, September 10). Comparing one- and two-way quantum repeater architectures. arXiv.org. https://arxiv.org/abs/2409.06152
- Main project repository and Experiment results: http://github.com/sagnikpal2004/QNet-MTP

## To Do List:
- Upstream [`RGate`](baseops/RGate.jl) to QuantumSymbolics.jl - in progress  [QuantumSymbolics.jl:Pull#95](https://github.com/QuantumSavory/QuantumSymbolics.jl/pull/95)
- [`DEJMPSProtocol`](noisyops/CircuitZoo.jl) is also missing from QuantumSavory.jl - in progress [QuantumSavory.jl:Issue#237](https://github.com/QuantumSavory/QuantumSavory.jl/issues/237)
- Modify measurement error model to integrate into the projectors themselves instead of using a random number to flip the measurement using [`project_traceout!`](noisyops/traceout.jl) (Do we need a `project_traceout!` that can work with POVM as well and not just Kets?)
- Figure out a better way to do noisy [`apply!`](noisyops/apply.jl)