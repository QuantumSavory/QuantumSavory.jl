# A Simulation of the Simple Entanglement Switch with random assignment

The switch is connected to n clients.
The switch has m qubit slots and the clients have a single qubit slot.
The switch initiates m entanglement attempts per clock tick with m clients uniformly at random.
Once entangled links are established among the qubits at the switch and its clients, the switch performs entanglement swaps on the respective links. Note: As the switch randomly selects pairs of clients to entangle, the protocol operates without user requests / backlog priorisation.

<!-- The `setup.jl` file implements all necessary base functionality.
The other files run the simulation and generate visuals in a number of different circumstances:
1. An interactive simulation with GLMakie visualization;
2. A web-app version of the simulation. -->

