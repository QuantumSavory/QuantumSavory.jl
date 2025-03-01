# A Simple Simulation of First Generation Quantum Repeater Chain

The `setup.jl` file implements all necessary base functionality.
The other files run the simulation and generate visuals in a number of different circumstances:
1. Just running an entangling process;
2. An entangling and swapping processes;
3. Entangling, swapping, and purification processes;
4. The same, but with additional figure-of-merit visualizations.

All of the above examples simulate the entire wave function of each qubit through a Schroedinger/Lindblad type of dynamics.

QuantumSavory permits swapping the backend simulator. In particular it is very easy to run the simulations using the Clifford formalism: the `*_clifford_setup.jl` file implements the few additional steps necessary for a tableau-based simulation, which can be much more efficient; then `5_clifford_full_example.jl` simply re-runs the same code as the wavefunction-based examples from above.

Lastly, `6_compare_formalisms.jl` runs repeated trajectory using either representation and compares their average results. The `*_noplot.jl` file runs the same simulation without creating plots.

For detailed description of the code consult the `QuantumSavory.jl`
[example page in the documentation](https://quantumsavory.github.io/QuantumSavory.jl/dev/howto-firstgenrepeater/)

**Importantly, you probably do not want to use this setup directly if all you want is to run a simple repeater chain!!!** This is a very low-level implementation. You would be better of using already implemented reusable protocols like [`EntanglerProt`](https://qs.quantumsavory.org/dev/API_ProtocolZoo/#QuantumSavory.ProtocolZoo.EntanglerProt). On the other hand, the setup here is a simple way to learn about making discrete event simulations without depending on a lot of extra library functionality and opaque black boxes. The `firstgenrepeater_v2` is a much higher level, easier to reuse, implementation of the same simulation.

Documentation:

- [The "How To" doc page on setting up this simulation of a repeater chain](https://qs.quantumsavory.org/dev/howto/firstgenrepeater/firstgenrepeater)
- [The same simulation but done with way less code thanks to better higher-level tools in QuantumSavory](https://qs.quantumsavory.org/dev/howto/firstgenrepeater_v2/firstgenrepeater_v2)