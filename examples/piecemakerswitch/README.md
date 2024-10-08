# System Overview
A central switch node connects to **n** clients. The switch possesses **m = n + 1** qubit slots, while each client has a single qubit slot.

# Entanglement Initiation
At each clock tick, the switch initiates entanglement attempts with each of the **n** clients, resulting in **n** entanglement processes per cycle. Successful entanglement links are then merged into a GHZ (Greenberger–Horne–Zeilinger) state using an additional "piecemaker" qubit located in the \((n + 1)\)th slot of the switch node. This fusion process is assumed to occur instantaneously. Once all clients went through the fusion operation, the piecemaker qubit is measured out. This completes the fusing process and all nodes are sharing an n-GHZ state.

# Fusion Operation
The fusion operation consists of applying a **CNOT** gate followed by a measurement in the computational basis. This procedure allows the merging of two GHZ states into a single GHZ state, modulo any required Pauli corrections. We iterate over all existing entangled states with the switch node: in each iteration, the piecemaker qubit (initialized in the state \(|+\rangle\)) is fused with one of the existing entangled states. 

# Noise 
The memories residing the nodes' `Register`s suffer from depolarizing noise. The latter is modelled via Kraus operators applied to the current state's density matrix.

### Troubleshooting
In the current implementation, sending and receiving classical measurement messages is achieved via a `DelayQueue` channel connected to `MessageBuffer`s at the nodes. The `MessageBuffer` acts as a buffer that holds incoming messages and manages processes waiting for messages.

Important Note: By design, message passing should not involve simulated time delays by default. Messages are expected to be delivered instantaneously in simulation time unless explicitly specified otherwise. However, during simulation, the following debug output from the EntanglementTracker indicates that a delay is being introduced unexpectedly: `@debug "EntanglementTracker @$(prot.node): Starting message wait at $(now(prot.sim)) with MessageBuffer containing: $(mb.buffer)"` in the `EntanglementTracker`. This results in distribution times > # rounds of entanglement attempts, which should not be the case.