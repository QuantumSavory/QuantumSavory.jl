# Simulations of the generation of GHZ and 3×2 cluster states in Tin-vacancy color centers

Live version is at [areweentangledyet.com/colorcentermodularcluster/](https://areweentangledyet.com/colorcentermodularcluster/).

Cluster states are highly entangled state of qubits useful as a computational resource. The cluster state is also a graph state where the graph has a 2D grid topology.

**Importantly, you probably do not want to use this setup directly if all you want is to model entanglement generation between neighbors!!!** This is a very low-level implementation. You would be better of using already implemented reusable protocols in [`QuantumSavory.ProtocolZoo`](https://qs.quantumsavory.org/dev/API_ProtocolZoo/) and the [tagging/querying capabilities for tracking of classical metadata and messages](https://qs.quantumsavory.org/dev/tag_query/). On the other hand, the setup here is a simple way to learn about how such protocols are implemented without using these higher-level capabilities.

This simulation is very similar to the hardware proposed in
["Percolation-based architecture for cluster state creation using photon-mediated entanglement between atomic memories"](https://www.nature.com/articles/s41534-019-0215-2)

The `setup.jl` file implements all necessary base functionality.
The other files run the simulation and generate visuals in a number of different circumstances:

1. Simulating many separate instances of the cluster state generation and provides statistics;
2. Simulating a single instance, but with more detailed visualizations;
3. An interactive webapp containing the aforementioned simulations.

Documentation:

- [The "How To" doc page on setting up a cluster state generation simulation](https://qs.quantumsavory.org/dev/howto/colorcentermodularcluster/colorcentermodularcluster)