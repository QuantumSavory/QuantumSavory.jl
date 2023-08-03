# A Simulation of Congestion on a Quantum Repeater Chain

For detailed description of the code consult the `QuantumSavory.jl`
[example page in the documentation](https://quantumsavory.github.io/QuantumSavory.jl/dev/howto-congestionchain/)

A simple, more instructive, example is also
[available in the documentation](https://quantumsavory.github.io/QuantumSavory.jl/dev/howto-firstgenrepeater/)


The `setup.jl` file implements all necessary base functionality.
The other files run the simulation and generate visuals in a number of different circumstances:
1. A single simulator script convenient for exploratory coding, running one single Monte Carlo simulation of a repeater chain;
2. A web-app version of the simulator;
3. A script running thousands of simulations like the ones in point 1, followed by plotting average statistical results for these simulations for a variety of repeater chain lengths.