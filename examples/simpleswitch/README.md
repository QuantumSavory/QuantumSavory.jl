# A Simple Entanglement Switch

Here we have one switch connected to n clients.
The switch has m qubit slots and the clients have a single qubit slot.
The switch can initiate m entanglement attempts per clock tick with m clients.
The switch can also perform entanglement swaps.
A client can send requests to the switch declaring they want to be entangled to another client.
The switch decides on which of these requests to attempt to satisfy first, aiming to reduce the backlog of requests it has.

The `setup.jl` file implements all necessary base functionality.
The other files run the simulation and generate visuals in a number of different circumstances:
1. An interactive simulation with GLMakie visualization;
2. A web-app version of the simulation.

Documentation:

- [`QuantumSavory.ProtocolZoo.SimpleSwitchDiscreteProt`](https://qs.quantumsavory.org/dev/API_ProtocolZoo/#QuantumSavory.ProtocolZoo.SimpleSwitchDiscreteProt)
- [The "How To" doc page on setting up a simple switch](https://qs.quantumsavory.org/dev/howto/simpleswitch/simpleswitch)