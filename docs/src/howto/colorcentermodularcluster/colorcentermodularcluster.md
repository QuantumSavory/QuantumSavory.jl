# [Cluster State on Color Centers](@id Cluster-State-on-Color-Centers)

!!! info "TODO Unfinished"
    This page is unfinished!

[Cluster states](https://en.wikipedia.org/wiki/Cluster_state) are highly entangled state of qubits useful as a [computational resource](https://en.wikipedia.org/wiki/One-way_quantum_computer).
The cluster state is also a [graph state](https://en.wikipedia.org/wiki/Graph_state) where the graph has a 2D grid topology.

One interesting hardware implementation involves entangling a large number of color centers[^1].

[^1]: [choi2019percolation](@cite)

We will build a simulator for such a piece of hardware.
Each node will be a register of one electron spin for networking and one nuclear spin in which the actual long-term entanglement is "stored".

!!! info "Low Level Implementation"
    This is a very low-level implementation. You would be better of using already implemented reusable protocols like [`EntanglerProt`](https://qs.quantumsavory.org/dev/API_ProtocolZoo/#QuantumSavory.ProtocolZoo.EntanglerProt). On the other hand, the setup here is a simple way to learn about making discrete event simulations without depending on a lot of extra library functionality and opaque black boxes.

The visualization below shows an example of the state being generated, together with tracking the state of various locks and other metadata that needs to be tracked.

```@raw html
<video src="../colorcentermodularcluster-02.simdashboard.mp4" autoplay loop muted></video>
```

Of interest is both the time it takes to prepare a full cluster state, as well as the fidelity of state being prepared in that fashion.
The fidelity can be lowered due to the numerous noise processes experience by the hardware.
The duration can be quite long due to the low efficiencies of photon capture during typical entanglement procedures.
The plot below shows the distribution of these figures of merit, sampled from a large number of independent runs of the simulation (gathering the entirety of this date takes less than a second).

![Time to cluster preparation versus fidelity of cluster](./colorcentermodularcluster-01.timetoconnection.png)

For organizing the simulation and simplifying the digital and analog quantum dynamics,
we will use the star of `QuantumSavory.jl`, namely the [`Register`](@ref) data structure.
For a convenient data structure to track per-node metadata in a graph (network) we will use the [`RegisterNet`](@ref) structure.

Moreover, behind the scenes `QuantumSavory.jl` will use:

- `ConcurrentSim.jl` for discrete event scheduling and simulation;
- `Makie.jl` together with our custom plotting recipes for visualizations;
- `QuantumOptics.jl` for low-level quantum states.

The user does not need to know much about these libraries, but if they wish, it is easy for them to peek behind the scenes and customize their use.

Below we embed a live version of the simulation (hosted at [areweentangledyet.com/colorcentermodularcluster/](https://areweentangledyet.com/colorcentermodularcluster/)):

```@raw html
<iframe src="https://areweentangledyet.com/colorcentermodularcluster/" style="height:850px;width:1250px;"></iframe>
```

The source code is in the [`examples/colorcentermodularcluster`](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/colorcentermodularcluster) folder.