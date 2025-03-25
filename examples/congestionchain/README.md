# A Simulation of Congestion on a Quantum Repeater Chain

Live version is at [areweentangledyet.com/congestionchain/](https://areweentangledyet.com/congestionchain/).

A simple example to study congestion on a chain of quantum repeaters.

**Importantly, you probably do not want to use this setup directly if all you want is to model entanglement generation between neighbors!!!** This is a very low-level implementation. You would be better of using already implemented reusable protocols like [`EntanglerProt`](https://qs.quantumsavory.org/dev/API_ProtocolZoo/#QuantumSavory.ProtocolZoo.EntanglerProt). On the other hand, the setup here is a simple way to learn about making discrete event simulations without depending on a lot of extra library functionality and opaque black boxes.

The `setup.jl` file implements all necessary base functionality.
The other files run the simulation and generate visuals in a number of different circumstances:
1. A single simulator script convenient for exploratory coding, running one single Monte Carlo simulation of a repeater chain;
2. A web-app version of the simulator;
3. A script running thousands of simulations like the ones in point 1, followed by plotting average statistical results for these simulations for a variety of repeater chain lengths.

Documentation:

- [The "How To" doc page on setting up this simulation of a repeater chain](https://qs.quantumsavory.org/dev/howto/congestionchain/congestionchain)
- [A more detailed example studying a first generation repeater chain](https://qs.quantumsavory.org/dev/howto/firstgenrepeater/firstgenrepeater)