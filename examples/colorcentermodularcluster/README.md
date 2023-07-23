# Simulations of the generation of GHZ and 3×2 cluster states in Tin-vacancy color centers

Cluster states are highly entangled state of qubits useful as a computational resource. The cluster state is also a graph state where the graph has a 2D grid topology.

This simulation is very similar to the hardware proposed in
["Percolation-based architecture for cluster state creation using photon-mediated entanglement between atomic memories"](https://www.nature.com/articles/s41534-019-0215-2)

For detailed description of the code consult the `QuantumSavory.jl`
[example page in the documentation](https://quantumsavory.github.io/QuantumSavory.jl/dev/howto/colorcentermodularcluster/colorcentermodularcluster/)

The `setup.jl` file implements all necessary base functionality.
The other files run the simulation and generate visuals in a number of different circumstances:

1. Simulating many separate instances of the cluster state generation and provides statistics;
2. Simulating a single instance, but with more detailed visualizations;
3. An interactive webapp containing the aforementioned simulations.