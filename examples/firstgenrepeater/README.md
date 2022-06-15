# A Simple Simulation of First Generation Quantum Repeater Chain

A limited public demo of a fraction of some internal research code. Full code to be release shortly.

For detailed description of the code consult the `QuantumSavory.jl`
[example page in the documentation](https://krastanov.github.io/QuantumSavory.jl/dev/howto-firstgenrepeater/)

The `*_setup.jl` file implements all necessary base functionality.
The other files run the simulation and generate visuals in a number of different circumstances:
- Just running an entangling process;
- An entangling and swapping processes;
- Entangling, swapping, and purification processes;
- The same, but with additional figure-of-merit visualizations.