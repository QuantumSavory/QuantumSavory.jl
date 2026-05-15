# Adaptive Quantum Repeater Chain with Fidelity Tracking

A network of quantum repeaters forming a chain, where repeaters autonomously decide when to purify based on **measured fidelity degradation**. This demonstrates how quantum networks can self-optimize without external intervention.

## What it shows

- **3 quantum repeaters** in a line, each with memory qubits subject to decoherence
- **Entanglement generation** between adjacent nodes at configurable rates
- **Entanglement swapping** at the middle node to establish end-to-end links
- **Adaptive purification**: repeaters track Bell pair fidelity and trigger purification when fidelity drops below a threshold
- **Interactive controls**: sliders to adjust entanglement attempt rate, purification threshold, and decoherence time
- **Real-time plots**: fidelity over time, entanglement success rate, and a register network visualization

## Structure

- `setup.jl` — The simulation logic: entangler, swapper, adaptive purifier, and network setup
- `1_interactive_visualization.jl` — GLMakie interactive dashboard
- `2_no_vis_cli.jl` — Same simulation without plots, suitable for headless benchmarking

## Run

```julia
# Install dependencies first (if not already done)
# using Pkg; Pkg.add(["GLMakie", "Graphs", "ResumableFunctions", "ConcurrentSim", "Distributions"])

# Then run:
include("1_interactive_visualization.jl")
```

Documentation:
- [QuantumSavory repeater chain how-to](https://qs.quantumsavory.org/dev/howto/firstgenrepeater/firstgenrepeater)
- [`ProtocolZoo` API](https://qs.quantumsavory.org/dev/API_ProtocolZoo/)
