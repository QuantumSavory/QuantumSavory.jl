# A Simple Simulation of First Generation Quantum Repeater Chain

For detailed description of the code consult the `QuantumSavory.jl`
[example page in the documentation](https://krastanov.github.io/QuantumSavory.jl/dev/howto-firstgenrepeater/)

The `setup.jl` file implements all necessary base functionality.
The other files run the simulation and generate visuals in a number of different circumstances:
1. Just running an entangling process;
2. An entangling and swapping processes;
3. Entangling, swapping, and purification processes;
4. The same, but with additional figure-of-merit visualizations.

All of the above examples simulate the entire wave function of each qubit through a Schroedinger/Lindblad type of dynamics.

## Clifford Simulations

The `*_clifford_setup.jl` file implements the few additional steps necessary for a tableau-based simulation, which can be much more efficient. Then `5_clifford_full_example.jl` simply re-runs the same code as the wavefunction-based examples from above.

Lastly, `6_compare_formalisms.jl` runs repeated trajectory using either representation and compares their average results. The `*_noplot.jl` file runs the same simulation without creating plots.