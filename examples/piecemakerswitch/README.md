# System Overview
A central switch node connects to $n$ clients. The switch possesses $m = n + 1$ qubit slots, while each client has a single qubit slot.

# Entanglement Initiation
At each clock tick, the switch initiates entanglement attempts with each of the $n$ clients, resulting in $n$ entanglement processes per cycle. Successful entanglement links are then merged into a GHZ (Greenberger–Horne–Zeilinger) state using an additional "piecemaker" qubit located in the $(n + 1)$th slot of the switch node. This fusion process is assumed to occur instantaneously. Once all clients went through the fusion operation, the piecemaker qubit is measured out. This completes the fusing process and all nodes are sharing an n-GHZ state.

# Fusion Operation
The fusion operation consists of applying a `CNOT` gate followed by a measurement in the computational basis. This procedure allows the merging of two GHZ states into a single GHZ state, modulo any required Pauli corrections. We iterate over all existing entangled states with the switch node: in each iteration, the piecemaker qubit (initialized in the state $|+\rangle$) is fused with one of the existing entangled states. 

# Noise 
The memories residing the nodes' `Register`s suffer from depolarizing noise. 

### Protocol flow

```mermaid
sequenceDiagram
    participant Client1
    participant ClientN

    participant SwitchNode
    participant Log

    Note over Client1,SwitchNode: Round 1 (1 unit time)
    par Entanglement Generation
        Client1->>+SwitchNode: Try to generate entanglement
        ClientN->>+SwitchNode: Try to generate entanglement
    end

    SwitchNode->>SwitchNode: Run fusions with successful clients

    par Send Measurement Outcomes
        SwitchNode-->>-Client1: Send measurement outcomes
        SwitchNode-->>-ClientN: Send measurement outcomes
    end

    par Apply Corrections (No time cost)
        Client1->>Client1: Apply correction gates
        ClientN->>ClientN: Apply correction gates
    end

    loop Check Fusion Status (No time cost)
        SwitchNode->>SwitchNode: Check if all clients are fused
        alt All clients fused
            SwitchNode->>SwitchNode: Measure piecemaker
            SwitchNode->>SwitchNode: Compute fidelity to GHZ state
            SwitchNode->>Log: Log fidelity and time
            SwitchNode->>SwitchNode: Trigger STOP
        else
            SwitchNode->>SwitchNode: Keep checking
        end
    end
```